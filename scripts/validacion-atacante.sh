#!/bin/bash
# Validación de las defensas desde una máquina NO confiable (p. ej. Kali), sin la CA del laboratorio.
# Es la vista de alguien de fuera: comprueba que solo responde lo que tiene que responder y que lo demás
# falla. No explota nada, no prueba contraseñas, no hace DoS: solo sondea y mira cómo contesta el sistema.
# Cada sondeo, además, deja rastro en Suricata (lo correlacionas en la VM, ver validacion-ofensiva.md).
#
# Uso:  bash scripts/validacion-atacante.sh IP_VM [dominio]
#   ej: bash scripts/validacion-atacante.sh 172.16.181.132 portal.opsmatrix.test

IP=${1:?Falta la IP de la VM. Uso: bash scripts/validacion-atacante.sh IP_VM [dominio]}
D=${2:-portal.opsmatrix.test}

echo "===== 0. DESDE DÓNDE ATACO ====="
date -u +"%Y-%m-%dT%H:%M:%SZ"
echo "mi IP: $(ip -4 -br addr 2>/dev/null | awk '$1!="lo"{print $3; exit}')"
echo "objetivo: $IP ($D)"

echo
echo "===== 1. ¿ESTÁ VIVO? (ping -> debe disparar la regla 1000001) ====="
ping -c 2 -W 2 "$IP" | grep -E "packets transmitted|bytes from" || echo "sin respuesta a ping"

echo
echo "===== 2. ESCANEO DE PUERTOS (solo deben contestar 22/80/443) ====="
if command -v nmap >/dev/null 2>&1; then
  nmap -Pn -p 22,80,443,3306,5000 -T4 "$IP" | grep -E "^[0-9]+/tcp|Nmap scan report"
else
  echo "(sin nmap; uso nc)"
  for p in 22 80 443 3306 5000; do
    nc -z -w3 "$IP" "$p" 2>/dev/null && echo "$p/tcp abierto" || echo "$p/tcp cerrado o filtrado"
  done
fi

echo
echo "===== 3. HTTPS SIN LA CA (un extraño NO debe confiar en el certificado) ====="
curl -s -o /dev/null -w "codigo=%{http_code} verificacion_tls=%{ssl_verify_result}\n" \
  --resolve "$D:443:$IP" "https://$D/" \
  && echo "(ha confiado: MAL)" \
  || echo "exit $?  -> rechazado por no conocer la CA (BIEN). exit 60 = certificado no confiable"

echo
echo "===== 4. IGNORAR LA CONFIANZA A LA FUERZA (curl -k): se ve el certificado pero sigue sin ser mío ====="
curl -sk -o /dev/null -w "con -k: codigo=%{http_code}\n" --resolve "$D:443:$IP" "https://$D/"
echo "-> -k solo demuestra que un atacante puede saltarse la verificación en SU cliente;"
echo "   no le da la clave del servidor ni le deja suplantarlo ante quien sí verifica."

echo
echo "===== 5. FORZAR TLS OBSOLETO (1.0 y 1.1 -> el servidor debe cortar) ====="
for v in tls1 tls1_1; do
  echo "-- $v"
  openssl s_client -connect "$IP:443" -servername "$D" -"$v" -cipher 'DEFAULT@SECLEVEL=0' -brief </dev/null 2>&1 \
    | grep -iE "protocol|alert|no protocols|handshake failure" | head -1
done

echo
echo "===== 6. ATACAR LA BBDD Y LA APP DIRECTAMENTE (3306 y 5000 -> no deben estar) ====="
for p in 3306 5000; do
  nc -z -w3 "$IP" "$p" 2>/dev/null && echo "$p alcanzable (MAL)" || echo "$p no alcanzable (BIEN)"
done

echo
echo "===== 7. BANNER DE NGINX (no debe decir la versión) ====="
curl -sI --resolve "$D:80:$IP" "http://$D/" | grep -i "^server:" || echo "(sin cabecera Server)"

echo
echo "===== FIN ====="
echo "Ahora, en la VM, correlaciona lo de arriba con Suricata (validacion-ofensiva.md):"
echo "  sudo grep -E '1000001|1000002|1000003' /var/log/suricata/fast.log | tail -20"
