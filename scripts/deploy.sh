#!/bin/bash
# OpsMatrix Lab - despliegue (MF0489)
# Uso (desde la raíz del repo, en la VM): bash scripts/deploy.sh
# Necesita los certificados de la Fase 2 en /etc/ssl/ (ver docs/mf0489/guia-despliegue.md)

cd "$(dirname "$0")/.." || exit 1

# 1. Comprobar que está todo lo necesario
if ! docker compose version > /dev/null 2>&1; then
    echo "[!] Falta Docker con el plugin compose"
    exit 1
fi

for f in /etc/ssl/certs/servidor.crt /etc/ssl/mf0489/ca.crt; do
    if [ ! -f "$f" ]; then
        echo "[!] No encuentro $f (hacer antes la Fase 2)"
        exit 1
    fi
done
if ! sudo test -f /etc/ssl/private/servidor.key; then
    echo "[!] No encuentro /etc/ssl/private/servidor.key (hacer antes la Fase 2)"
    exit 1
fi

# 2. Crear el .env con contraseñas aleatorias si no existe
if [ ! -f .env ]; then
    echo "[+] Creando .env con contraseñas nuevas"
    cp .env.example .env
    sed -i "s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(openssl rand -base64 24)|" .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -base64 24)|" .env
    chmod 600 .env
else
    echo "[=] Ya hay .env, no lo toco"
fi

# 3. Comprobar el compose y levantar (nunca "down -v": borraría la BBDD)
docker compose config --quiet || exit 1
docker compose up -d --build

# 4. Estado
sleep 10
docker compose ps
docker compose exec -T reverse-proxy nginx -t
echo "[OK] Desplegado. Comprobar con: bash scripts/check-vm.sh"
