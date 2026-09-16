#!/usr/bin/env bash

# Configuración de rutas
WORKLOG_FILE="docs/WORKLOG.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S CEST")
DATE_HEADER=$(date +"%Y-%m-%d")

echo "==> [OpsMatrix-Lab] Iniciando auditoría y sincronización automatizada..."

# 1. Capturar archivos modificados en staged / unstaged
STAGED_FILES=$(git status --porcelain | awk '{print $2}')

if [ -z "$STAGED_FILES" ]; then
    echo "[-] No hay cambios detectados para auditar."
    exit 0
fi

# 2. Generar entrada automática en WORKLOG.md
echo "==> Registrando evidencia en $WORKLOG_FILE..."

if [ ! -f "$WORKLOG_FILE" ]; then
    mkdir -p docs
    echo "# OpsMatrix-Lab — Daily Operational Worklog & Audit Trail" > "$WORKLOG_FILE"
fi

{
    echo ""
    echo "### [$TIMESTAMP] - Automated Execution & Evidence Capture"
    echo "**Archivos Afectados:**"
    for file in $STAGED_FILES; do
        echo "* \`$file\`"
    done
    echo ""
    echo "**Diff Resumido de Cambios:**"
    echo "\`\`\`diff"
    git diff --stat
    echo "\`\`\`"
    echo "---"
} >> "$WORKLOG_FILE"

# 3. Empaquetar cambios e incluir la evidencia en el commit
git add .
COMMIT_MSG="auto(audit): evidencias y cambios registrados [$TIMESTAMP]"

git commit -m "$COMMIT_MSG" || true

# 4. Sincronizar con GitHub si se pasa el argumento 'local' o 'push'
if [ "$1" == "local" ] || [ "$1" == "push" ]; then
    echo "==> Sincronizando repositorio con GitHub (main)..."
    git push origin main
fi

echo "[+] Proceso de auditoría y sync completado con éxito."
