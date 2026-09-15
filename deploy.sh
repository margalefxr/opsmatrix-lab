#!/usr/bin/env bash
# ==============================================================================
# OpsMatrix-Lab — Script de Bootstrapping & Despliegue Automatizado
# Uso: ./deploy.sh
# ==============================================================================

set -euo pipefail

GREEN='\030[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[+] Iniciando bootstrapping de OpsMatrix-Lab...${NC}"

# 1. Comprobar dependencias del sistema
command -v docker >/dev/null 2>&1 || { echo -e "${RED}[!] Docker no está instalado.${NC}" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo -e "${RED}[!] Docker Compose plugin no está instalado.${NC}" >&2; exit 1; }

# 2. Posicionamiento en directorio de Docker
DOCKER_DIR="layer3-services/docker"

if [ ! -d "$DOCKER_DIR" ]; then
    echo -e "${RED}[!] Directorio $DOCKER_DIR no encontrado.${NC}"
    exit 1
fi

cd "$DOCKER_DIR"

# 3. Generar .env desde plantilla si no existe
if [ ! -f .env ]; then
    echo -e "${GREEN}[+] Generando archivo .env desde .env.example...${NC}"
    cp .env.example .env
fi

# 4. Levantar la infraestructura
echo -e "${GREEN}[+] Desplegando stack Docker (Nginx + MariaDB Aislada)...${NC}"
docker compose down --remove-orphans
docker compose up -d --build

# 5. Estado final de despliegue
echo -e "${GREEN}[+] Esperando inicialización de healthchecks...${NC}"
sleep 5
docker compose ps

echo -e "${GREEN}[OK] Infraestructura OpsMatrix-Lab desplegada y operativa.${NC}"
