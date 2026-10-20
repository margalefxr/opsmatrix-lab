#!/bin/bash
# Extra MF0489: revocación con CRL (en el Mac, donde vive la CA)
# 1. Apunta en la base de datos de la CA el certificado real (servidor.crt)
# 2. Emite un certificado de prueba, lo revoca (keyCompromise) y publica la CRL
# 3. Comprueba que el revocado se rechaza y el real sigue valiendo
# Pide la contraseña de ca.key cuatro veces. No muestra ninguna clave.
# Uso: bash scripts/pki-revocacion.sh 2>&1 | tee pki-revocacion.txt
# (ca.cnf y prueba.ext se cogen de layer2-perimeter/pki/ o de la misma carpeta que el script)

AQUI=$(cd "$(dirname "$0")" && pwd)
PKI="$AQUI/../layer2-perimeter/pki"
[ -f "$PKI/ca.cnf" ] || PKI="$AQUI"
CA_DIR=~/ca_root-pki/ca
IP=172.16.181.132
D=portal.opsmatrix.test
cd $CA_DIR || exit 1

cp "$PKI/ca.cnf" "$PKI/prueba.ext" .
mkdir -p crl
touch index.txt
[ -f crlnumber ] || echo 01 > crlnumber

echo "===== 1. Registrar servidor.crt en la base de datos de la CA ====="
grep -q "CN=$D" index.txt || openssl ca -config ca.cnf -valid emitidos/servidor.crt

echo
echo "===== 2. Certificado de prueba (simula uno robado) ====="
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out prueba.key 2>/dev/null
openssl req -new -key prueba.key -subj "/CN=prueba-revocacion.opsmatrix.test" -out solicitudes/prueba.csr
openssl ca -config ca.cnf -batch -in solicitudes/prueba.csr -out emitidos/prueba.crt -extfile prueba.ext
rm -f prueba.key   # la clave de prueba no hace falta para nada más

echo
echo "===== 3. Revocar y publicar la CRL ====="
openssl ca -config ca.cnf -revoke emitidos/prueba.crt -crl_reason keyCompromise
openssl ca -config ca.cnf -gencrl -crlexts ext_crl -out crl/ca.crl
cat index.txt
openssl crl -in crl/ca.crl -noout -lastupdate -nextupdate
openssl crl -in crl/ca.crl -noout -text | grep -E "Serial Number|Reason Code" -A1 | grep -v "^--"

echo
echo "===== 4. Comprobar ====="
echo "-- certificado revocado (debe fallar con error 23):"
openssl verify -crl_check -CAfile ca.crt -CRLfile crl/ca.crl emitidos/prueba.crt
echo "-- certificado real (debe dar OK):"
openssl verify -crl_check -CAfile ca.crt -CRLfile crl/ca.crl -purpose sslserver -verify_hostname $D emitidos/servidor.crt
echo "-- conexión real a Nginx comprobando también la CRL:"
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -CRL crl/ca.crl -crl_check -verify_hostname $D -verify_return_error -brief </dev/null 2>&1 | grep -E "Verification|error"

echo
echo "===== 5. SSH: intercambio de claves negociado ====="
ssh -v -o BatchMode=yes server@$IP exit 2>&1 | grep -E "kex: algorithm|Remote protocol version|host key algorithm" | head -3

# La CRL es pública: se deja junto a ca.cnf para subirla al repo
cp crl/ca.crl "$PKI/ca.crl"
echo
echo "===== FIN ====="
