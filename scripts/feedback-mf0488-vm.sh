#!/bin/bash
# Evidencias que pidió el profesor en el feedback del MF0488
# Antes, desde el Mac: ping -c 4 172.16.181.132  (y un intento de SSH con contraseña)
# Uso (desde la raíz del repo, en la VM): bash scripts/feedback-mf0488-vm.sh 2>&1 | tee feedback-mf0488.txt

cd "$(dirname "$0")/.." || exit 1
sudo -v
date -u

echo "===== 1. Suricata activo y en qué interfaz ====="
systemctl status suricata --no-pager | head -5
grep -nE "^\s*- interface:" /etc/suricata/suricata.yaml | head -1

echo
echo "===== 2. suricata -T y HOME_NET ====="
sudo suricata -T -c /etc/suricata/suricata.yaml 2>&1 | tail -2
grep -nE "^\s*HOME_NET:" /etc/suricata/suricata.yaml

echo
echo "===== 3. Regla 1000001 cargada ====="
grep -n "sid:1000001" /var/lib/suricata/rules/local.rules

echo
echo "===== 4. Alerta del ping en fast.log ====="
sudo grep "1:1000001:" /var/log/suricata/fast.log | tail -4

echo
echo "===== 5. La misma alerta en eve.json ====="
sudo jq -c 'select(.event_type=="alert" and .alert.signature_id==1000001) | {timestamp, src_ip, dest_ip, proto, icmp_type, sid: .alert.signature_id, msg: .alert.signature}' /var/log/suricata/eve.json | tail -4

echo
echo "===== 6. SSH: entrada con clave y intento con contraseña rechazado ====="
sudo journalctl -u ssh --since "-2h" --no-pager | grep -E "Accepted publickey|Failed|authenticating user|preauth" | tail -5

echo
echo "===== 7. Nginx: peticiones 200 y 404 ====="
docker compose logs --no-log-prefix reverse-proxy 2>/dev/null | grep -E "status=(200|404)" | tail -3

echo
echo "===== FIN ====="
