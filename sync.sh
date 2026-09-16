#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-local}

echo "[+] Ejecutando sincronización de trazabilidad (${TARGET})..."

if [ "$TARGET" = "local" ]; then
    git add .
    git commit -m "docs(audit): actualizar guia de demostracion en vivo" || true
    git push origin main
fi
