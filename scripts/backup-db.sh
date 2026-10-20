#!/bin/bash
# OpsMatrix Lab - copia de la base de datos y prueba de que se puede restaurar
# Uso (desde la raíz del repo, en la VM): bash scripts/backup-db.sh
# La copia se guarda en ~/backups (fuera del repo, no se sube a GitHub)

cd "$(dirname "$0")/.." || exit 1
mkdir -p ~/backups
chmod 700 ~/backups
COPIA=~/backups/opsmatrix-$(date +%F-%H%M).sql.gz

# 1. Copia (las contraseñas las coge el contenedor de su entorno, no salen por pantalla)
docker compose exec -T db sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' | gzip > "$COPIA"
chmod 600 "$COPIA"
ls -l "$COPIA"

# 2. Prueba de restauración en una base de datos aparte (no toca la buena)
echo "[+] Restaurando en restore_test..."
docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS restore_test; CREATE DATABASE restore_test;"'
gunzip -c "$COPIA" | docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" restore_test'

echo "visitas en la BBDD buena:"
docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM $MARIADB_DATABASE.visitas"'
echo "visitas en la copia restaurada:"
docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM restore_test.visitas"'

# 3. Borrar la base de prueba
docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "DROP DATABASE restore_test;"'
echo "[OK] Copia en $COPIA"
