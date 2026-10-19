#!/bin/bash
# Revisión desde el Mac (cliente + CA) · OpsMatrix MF0489
# Solo lee: no muestra la clave de la CA ni su contraseña.
# Uso: bash scripts/check-mac.sh 2>&1 | tee check-mac.txt
# Cambia IP y CA_DIR si tu laboratorio es distinto

IP=172.16.181.132
D=portal.opsmatrix.test
CA_DIR=~/ca_root-pki/ca   # carpeta con ca.crt
cd $CA_DIR || exit 1

echo "===== 1. CA (Entorno A) ====="
date
which openssl
openssl version
ls -l private/ca.key
ls -l ca.crt emitidos/servidor.crt
openssl x509 -in ca.crt -noout -subject -enddate
openssl verify -CAfile ca.crt ca.crt
openssl verify -CAfile ca.crt -purpose sslserver -verify_hostname "$D" emitidos/servidor.crt

echo
echo "===== 2. PUERTOS DE LA VM VISTOS DESDE FUERA ====="
for p in 22 80 443 3306 5000; do
  nc -z -w2 $IP $p 2>/dev/null && echo "$p abierto" || echo "$p cerrado"
done

echo
echo "===== 3. HTTP -> HTTPS ====="
curl -sI --resolve $D:80:$IP http://$D/prueba | grep -iE "^HTTP|^Server|^Location"

echo
echo "===== 4. HTTPS CON LA CA ====="
curl -s -w "\ncodigo=%{http_code} tls=%{ssl_verify_result}\n" --cacert ca.crt --resolve $D:443:$IP https://$D/

echo
echo "===== 5. SIN LA CA (debe fallar, exit 60) ====="
curl -s -o /dev/null --resolve $D:443:$IP https://$D/
echo "exit $?"

echo
echo "===== 6. NOMBRE EQUIVOCADO (debe fallar) ====="
curl -s -o /dev/null --cacert ca.crt --resolve otro.opsmatrix.test:443:$IP https://otro.opsmatrix.test/
echo "exit $?"

echo
echo "===== 7. OPENSSL S_CLIENT ====="
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -verify_hostname $D -verify_return_error -brief </dev/null 2>&1

echo
echo "===== 8. VERSIONES TLS ====="
for v in tls1_3 tls1_2 tls1_1; do
  echo "-- $v"
  openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -$v -cipher 'DEFAULT@SECLEVEL=0' -brief </dev/null 2>&1 | grep -E "Protocol version|Ciphersuite|alert|error|no protocols" | head -2
done

echo
echo "===== FIN ====="
