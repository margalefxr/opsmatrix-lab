#!/bin/bash
# Revisión completa de la VM (OpsMatrix · MF0489)
# Solo lee: no cambia nada ni muestra claves ni contraseñas.
# Uso (desde la raíz del repo): bash scripts/check-vm.sh 2>&1 | tee check-vm.txt

D=portal.opsmatrix.test
cd "$(dirname "$0")/.." || exit 1   # raíz del repo
sudo -v   # pide la contraseña una sola vez

echo "===== 1. SISTEMA ====="
date
hostname
uptime -p
ip -br addr show enp2s0
ip route | grep default

echo
echo "===== 2. SSH ====="
systemctl is-active ssh
sudo sshd -T | grep -E "^(port|passwordauthentication|pubkeyauthentication|permitrootlogin) "

echo
echo "===== 3. SURICATA ====="
systemctl is-active suricata
grep -nE "^\s*- interface:" /etc/suricata/suricata.yaml | head -3

echo
echo "===== 4. DOCKER ====="
docker --version
docker compose version
ip -4 -br addr show docker0

echo
echo "===== 5. CERTIFICADOS ====="
sudo ls -l /etc/ssl/private/servidor.key
ls -l /etc/ssl/certs/servidor.crt /etc/ssl/mf0489/ca.crt
openssl verify -CAfile /etc/ssl/mf0489/ca.crt -purpose sslserver -verify_hostname "$D" /etc/ssl/certs/servidor.crt
openssl x509 -in /etc/ssl/certs/servidor.crt -noout -enddate
echo "hash clave:       $(sudo openssl pkey -in /etc/ssl/private/servidor.key -pubout -outform DER | openssl dgst -sha256 | cut -d' ' -f2)"
echo "hash certificado: $(openssl x509 -in /etc/ssl/certs/servidor.crt -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 | cut -d' ' -f2)"
sudo find / -xdev -name "ca.key" 2>/dev/null | grep -q . && echo "ALERTA: hay un ca.key en la VM" || echo "OK: ningún ca.key en la VM"

echo
echo "===== 6. REPO Y SECRETOS ====="
git branch --show-current
git log --oneline -1
git status --short
ls -l .env
git check-ignore -q .env && echo "OK: .env ignorado por git"
git ls-files | grep -E "\.key$|\.env$|\.pem$" && echo "ALERTA: secretos en git" || echo "OK: ninguna clave ni .env en git"

echo
echo "===== 7. COMPOSE ====="
docker compose config --quiet && echo "OK: compose válido"
docker compose ps
docker compose exec -T reverse-proxy nginx -t

echo
echo "===== 8. PUERTOS EN EL HOST ====="
sudo ss -tulnp | grep -E ":(22|80|443|3306|5000)\b"

echo
echo "===== 9. REDES DOCKER ====="
for n in opsmatrix-lab_frontend_net opsmatrix-lab_backend_net; do
  echo "$n internal=$(docker network inspect $n -f '{{.Internal}}') contenedores: $(docker network inspect $n -f '{{range .Containers}}{{.Name}} {{end}}')"
done

echo
echo "===== 10. AISLAMIENTO ENTRE CONTENEDORES ====="
echo "-- proxy -> app (debe funcionar)"
docker compose exec -T reverse-proxy wget -qO- http://app:5000/ | head -c 120; echo
echo "-- proxy -> db (no debe ni resolver el nombre)"
docker compose exec -T reverse-proxy getent hosts db || echo "OK: el proxy no ve la BBDD"
echo "-- db -> internet (no debe salir)"
docker compose exec -T db timeout 3 bash -c "</dev/tcp/1.1.1.1/443" 2>/dev/null && echo "ALERTA: la BBDD sale a internet" || echo "OK: la BBDD no sale a internet"
echo "-- usuario de la app"
docker compose exec -T app id

echo
echo "===== 11. BASE DE DATOS ====="
docker volume inspect opsmatrix-lab_mariadb_data -f '{{.Name}} {{.Mountpoint}}'
docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT COUNT(*) AS visitas, MIN(fecha) AS primera, MAX(fecha) AS ultima FROM visitas"'

echo
echo "===== 12. LOGS RECIENTES ====="
docker compose logs --tail=5 reverse-proxy
docker compose logs --tail=5 app

echo
echo "===== 13. RESTOS PENDIENTES (FASE 5) ====="
docker network ls --format '{{.Name}}' | grep -E "^docker_"
sudo grep -cE "br-e2efeb52c253|10\.0\.[123]\." /etc/iptables/rules.v4
ls ~/backups/ 2>/dev/null

echo
echo "===== FIN ====="
