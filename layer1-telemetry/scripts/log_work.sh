#!/bin/bash
WORKLOG="docs/WORKLOG.md"
mkdir -p docs

echo "" >> "$WORKLOG"
echo "## Registro de Sesión: $(date '+\%Y-\%m-\%d \%H:\%M:\%S')" >> "$WORKLOG"
echo "* **Usuario:** $(whoami)" >> "$WORKLOG"
echo "* **Commit:** $(git log -1 --format="\%h - \%s")" >> "$WORKLOG"
echo '```text' >> "$WORKLOG"
git status -s >> "$WORKLOG"
echo '```' >> "$WORKLOG"
