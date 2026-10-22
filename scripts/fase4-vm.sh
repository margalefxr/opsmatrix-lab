#!/bin/bash
# Fase 4 · recoger lo que vieron tcpdump, Suricata y Nginx (VM)
# Lanzar DESPUÉS de fase4-mac.sh.
# Uso (desde la raíz del repo): bash scripts/fase4-vm.sh 2>&1 | tee fase4-vm.txt

D=portal.opsmatrix.test
cd "$(dirname "$0")/.." || exit 1
sudo -v

echo "===== 1. CONFIGURACION ACTIVA ====="
ip -br addr show enp2s0
grep -nE "^\s*- interface:" /etc/suricata/suricata.yaml | head -1
systemctl is-active suricata
grep -n "1000003" /var/lib/suricata/rules/local.rules
docker compose exec -T reverse-proxy nginx -T 2>/dev/null | grep -E "ssl_protocols|log_format mf0489"

echo
echo "===== 2. TCPDUMP PUERTO 80: ¿se ve la ruta? ====="
grep -c "" ~/f4/tcpdump-80.txt
grep -aE "GET |HEAD |Host:|Location:" ~/f4/tcpdump-80.txt | head -6

echo
echo "===== 3. TCPDUMP PUERTO 443: ¿se ve la ruta? ====="
grep -c "" ~/f4/tcpdump-443.txt
grep -ac "mf0489-prueba-https" ~/f4/tcpdump-443.txt
grep -aF "$D" ~/f4/tcpdump-443.txt | head -2
head -3 ~/f4/tcpdump-443.txt

echo
echo "===== 4. SURICATA fast.log (reglas propias) ====="
sudo grep -E "1000002|1000003" /var/log/suricata/fast.log | tail -8

echo
echo "===== 5. SURICATA eve.json: alertas SID 1000003 ====="
sudo jq -c 'select(.event_type == "alert" and .alert.signature_id == 1000003) | {timestamp, src_ip, src_port, dest_ip, dest_port, sid: .alert.signature_id, msg: .alert.signature}' /var/log/suricata/eve.json | tail -6

echo
echo "===== 6. SURICATA eve.json: eventos tls ====="
sudo jq -c 'select(.event_type == "tls" and .dest_port == 443) | {timestamp, src_ip, src_port, dest_ip, tls}' /var/log/suricata/eve.json | tail -4

echo
echo "===== 7. SURICATA eve.json: eventos http del 80 ====="
sudo jq -c 'select(.event_type == "http" and .dest_port == 80) | {timestamp, src_ip, http}' /var/log/suricata/eve.json | tail -2

echo
echo "===== 8. NGINX (log mf0489) ====="
docker compose logs --no-log-prefix reverse-proxy 2>/dev/null | grep "mf0489-" | tail -6

echo
echo "===== 9. CORRELACION ====="
echo "-- Nginx:"
docker compose logs --no-log-prefix reverse-proxy 2>/dev/null | grep "mf0489-correlacion-01"
echo "-- Suricata (misma IP y puerto de origen):"
P=$(docker compose logs --no-log-prefix reverse-proxy 2>/dev/null | grep "mf0489-correlacion-01" | tail -1 | grep -oE "client=[0-9.]+:[0-9]+" | cut -d: -f2)
echo "puerto origen en Nginx: $P"
sudo jq -c "select(.event_type == \"alert\" and .alert.signature_id == 1000003 and .src_port == $P) | {timestamp, src_ip, src_port, dest_ip, dest_port, sid: .alert.signature_id}" /var/log/suricata/eve.json
sudo grep ":$P -> " /var/log/suricata/fast.log | grep 1000003

echo
echo "===== 10. LA INFRAESTRUCTURA SIGUE BIEN (Actividad 19) ====="
docker compose ps --format "{{.Name}} {{.Status}} {{.Ports}}"
docker compose config --quiet && echo "OK: compose válido"
docker compose exec -T reverse-proxy nginx -t 2>&1 | tail -1
sudo ss -tlnp | grep -E ":(80|443|3306|5000)\b" | awk '{print $4}'
sudo ls -l /etc/ssl/private/servidor.key
docker inspect opsmatrix-proxy -f '{{range .Mounts}}{{.Destination}} rw={{.RW}}{{"\n"}}{{end}}'
sudo find / -xdev -name "ca.key" 2>/dev/null | grep -q . && echo "ALERTA: ca.key en la VM" || echo "OK: ningún ca.key en la VM"
docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -N -e "SELECT COUNT(*) FROM visitas"' | sed 's/^/visitas guardadas: /'

echo
echo "===== FIN ====="
