#!/bin/bash
# Revisión completa de la VM (OpsMatrix · MF0489)
# Solo lee y no muestra claves ni contraseñas. Lo único que cambia: la prueba proxy -> app (§10) suma una visita al contador.
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
echo "-- control: el proxy sí resuelve 'app' (getent funciona)"
docker compose exec -T reverse-proxy getent hosts app || echo "ALERTA: getent no funciona, la prueba siguiente no vale"
echo "-- proxy -> db (no debe ni resolver el nombre)"
docker compose exec -T reverse-proxy getent hosts db || echo "OK: el proxy no ve la BBDD"
# rc = código de salida de la conexión a 1.1.1.1:443. 0 = sale. 124 = timeout. 127 = falta el comando (prueba no válida)
echo "-- control: la app (frontend_net) sí sale a internet (la prueba funciona)"
r=$(docker compose exec -T app bash -c 'timeout 3 bash -c "</dev/tcp/1.1.1.1/443" 2>/dev/null; echo $?' | tr -d '\r')
[ "$r" = 0 ] && echo "control OK: la app sale (rc=$r)" || echo "ALERTA: la app tampoco sale (rc=$r), la prueba siguiente no vale"
echo "-- db -> internet (no debe salir)"
docker compose exec -T db bash -c 'for c in bash timeout; do command -v $c || echo "FALTA $c"; done'
r=$(docker compose exec -T db bash -c 'timeout 3 bash -c "</dev/tcp/1.1.1.1/443" 2>/dev/null; echo $?' | tr -d '\r')
case "$r" in
  0) echo "ALERTA: la BBDD sale a internet (rc=$r)" ;;
  126|127) echo "ALERTA: prueba no válida (rc=$r)" ;;
  *) echo "OK: la BBDD no sale a internet (rc=$r)" ;;
esac
echo "-- rutas de la BBDD (00000000 = ruta por defecto; no debe haber)"
docker compose exec -T db cat /proc/net/route | awk '{print $1, $2, $3}'
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
echo "===== 13. LIMPIEZA (FASE 5) ====="
echo "redes docker_* viejas: $(docker network ls --format '{{.Name}}' | grep -cE '^docker_')"
echo "netfilter-persistent: $(systemctl is-enabled netfilter-persistent 2>/dev/null)"
echo "reglas viejas cargadas: $(sudo iptables-save | grep -cE 'br-e2efeb52c253|10\.0\.[123]\.')"
ls ~/backups/ 2>/dev/null

echo
echo "===== FIN ====="
