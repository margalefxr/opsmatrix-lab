#!/bin/bash
# Script de trazabilidad automática para auditar el desarrollo en docs/WORKLOG.md

WORKLOG="docs/WORKLOG.md"

mkdir -p docs

echo "" >> "$WORKLOG"
echo "### Registro Automático: $(date '+\%Y-\%m-\%d \%H:\%M:\%S CEST')" >> "$WORKLOG"
echo "* **Usuario Local:** $(whoami)" >> "$WORKLOG"
echo "* **Host:** $(hostname)" >> "$WORKLOG"
echo "* **Rama Git:** $(git rev-parse --abbrev-ref HEAD 2>/dev/null \vert{}\vert{} echo "main")" >> "$WORKLOG"
echo "* **Último Commit:** $(git log -1 --format="\%h - \%s (\%ci)" 2>/dev/null \vert{}\vert{} echo "Inicial")" >> "$WORKLOG"
echo "" >> "$WORKLOG"
echo "#### Estado Actual de Archivos (Git Status):" >> "$WORKLOG"
echo '```text' >> "$WORKLOG"
git status -s >> "$WORKLOG"
echo '```' >> "$WORKLOG"
echo "---" >> "$WORKLOG"

echo "[OK] Evidencia inyectada correctamente en $WORKLOG"
