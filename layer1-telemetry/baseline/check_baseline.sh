#!/bin/bash
# ==============================================================================
# Script de Telemetría y Salud de Infraestructura - Layer 1 Baseline
# ==============================================================================

echo "=== [OPSMATRIX TELEMETRY BASELINE] ==="
echo "Fecha/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host: $(hostname) | IP: $(hostname -I | awk '{print $1}')"
echo "--------------------------------------------------"

# 1. Métricas del Host
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
RAM_USAGE=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
echo "[+] Uso de CPU: ${CPU_USAGE}%"
echo "[+] Uso de RAM: ${RAM_USAGE}"

# 2. Estado de Contenedores
echo "--------------------------------------------------"
echo "[+] Contenedores Docker Activos:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 3. Estado de Suricata IDS
echo "--------------------------------------------------"
SURICATA_STATUS=$(systemctl is-active suricata)
echo "[+] Servicio Suricata IDS: ${SURICATA_STATUS}"

if [ -f /var/log/suricata/eve.json ]; then
    ALERTS_COUNT=$(sudo grep -c '"event_type":"alert"' /var/log/suricata/eve.json 2>/dev/null || echo "0")
    echo "[+] Alertas Registradas en eve.json: ${ALERTS_COUNT}"
else
    echo "[!] Log eve.json aun no generado."
fi
echo "=================================================="
