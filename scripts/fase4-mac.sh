#!/bin/bash
# Fase 4 · pruebas desde el cliente (Mac)
# Lanzar mientras tcpdump está capturando en la VM.
# Uso: bash scripts/fase4-mac.sh 2>&1 | tee fase4-mac.txt

IP=172.16.181.132
D=portal.opsmatrix.test
CA_DIR=~/ca_root-pki/ca   # carpeta con ca.crt
cd $CA_DIR || exit 1

echo "===== 1. CONEXION HTTPS REAL (curl -v) ====="
date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -v --cacert ca.crt --resolve $D:443:$IP https://$D/ -o /dev/null 2>&1 | grep -E "SSL connection|subject:|issuer:|subjectAltName|SSL certificate verify|< HTTP"

echo
echo "===== 2. TLS 1.3 ====="
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -verify_hostname $D -verify_return_error -tls1_3 -brief </dev/null 2>&1

echo
echo "===== 3. TLS 1.2 ====="
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -verify_hostname $D -verify_return_error -tls1_2 -brief </dev/null 2>&1

echo
echo "===== 4. TLS 1.1 (debe fallar) ====="
echo "-- como pide el enunciado:"
openssl s_client -connect $IP:443 -servername $D -tls1_1 -brief </dev/null 2>&1 | head -3
echo "-- dejando que el cliente lo intente de verdad (SECLEVEL=0):"
openssl s_client -connect $IP:443 -servername $D -tls1_1 -cipher 'DEFAULT@SECLEVEL=0' -brief </dev/null 2>&1 | head -3

echo
echo "===== 5. PETICION HTTP (para tcpdump del 80) ====="
date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -sI --resolve $D:80:$IP http://$D/mf0489-prueba-http | grep -iE "^HTTP|^Location"

echo
echo "===== 6. PETICION HTTPS (para tcpdump del 443) ====="
date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -s -o /dev/null -w "HTTP %{http_code}\n" --cacert ca.crt --resolve $D:443:$IP https://$D/mf0489-prueba-https

echo
echo "===== 7. CORRELACION: una sola petición identificable ====="
sleep 3
date -u +"%Y-%m-%dT%H:%M:%SZ"
curl -s -o /dev/null -w "HTTP %{http_code} puerto_origen=%{local_port}\n" --cacert ca.crt --resolve $D:443:$IP https://$D/mf0489-correlacion-01

echo
echo "===== FIN ====="
