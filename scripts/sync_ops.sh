#!/usr/bin/env bash
# ==============================================================================
# Script de Automatización y Trazabilidad Operativa — OpsMatrix
# Autor: Xavier Margalef Riestra
# Descripción: Valida el estado de la infraestructura, registra la traza en el
#              WORKLOG y automatiza el ciclo de sincronización git.
# ==============================================================================

set -euo pipefail

LOG_FILE="docs/WORKLOG.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[*] Iniciando validación de estado operativo de OpsMatrix..."

# 1. Validación de contenedores y redes Docker (si el stack está desplegado)
if command -v docker >/dev/null 2>&1 && docker compose ps >/dev/null 2>&1; then
    echo "[*] Verificando estado de contenedores..."
    docker compose ps
else
    echo "[!] Docker Compose no disponible o stack no desplegado — se omite la validación de contenedores."
fi

# 2. Solo registra y sincroniza si hay cambios reales pendientes
CHANGED_FILES=$(git status --porcelain)
if [ -z "$CHANGED_FILES" ]; then
    echo "[-] No hay cambios para registrar ni sincronizar."
    exit 0
fi

# 3. Inserción de entrada en el WORKLOG con el diff real, no una plantilla fija
mkdir -p "$(dirname "$LOG_FILE")"
{
    echo ""
    echo "### Sincronización: $TIMESTAMP"
    echo "**Archivos afectados:**"
    echo '```text'
    echo "$CHANGED_FILES"
    echo '```'
    echo "---"
} >> "$LOG_FILE"

# 4. Sincronización Git controlada
git add .
read -r -p "Introduce el mensaje del commit: " COMMIT_MSG
git commit -m "ops: ${COMMIT_MSG:-sincronización de WORKLOG y cambios de infraestructura}"
git push origin main

echo "[OK] Sincronización y trazabilidad completadas."
