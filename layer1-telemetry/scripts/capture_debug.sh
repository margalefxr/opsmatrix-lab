#!/usr/bin/env bash
# Captura de fricción técnica / debugging automatizado
# Uso: ./layer1-telemetry/scripts/capture_debug.sh "Descripción del problema/error" "Solución o comando aplicado"

REASON=${1:-"Incidencia de entorno o sintaxis"}
SOLUTION=${2:-"Revisión de dependencias y reejecución"}
LOG_FILE="docs/WORKLOG.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat << INCIDENT >> "$LOG_FILE"

#### [TROUBLESHOOTING AUTOMÁTICO - $TIMESTAMP]
* **Conflicto / Error:** $REASON
* **Acción Correctiva:** $SOLUTION
INCIDENT

echo "[+] Evento de debugging registrado en WORKLOG.md"
