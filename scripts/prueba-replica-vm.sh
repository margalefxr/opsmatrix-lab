#!/bin/bash
# Prueba "persona nueva" en la VM, sin tocar el despliegue real:
#   - clon limpio de GitHub en ~/opsmatrix-replica
#   - proyecto Docker aparte (opsmatrix-replica): sus propios contenedores, redes y BBDD VACÍA
#   - puertos 8080/8443 solo en 127.0.0.1 (no se abren hacia fuera)
#   - usa deploy.sh tal cual, que crea un .env nuevo con contraseñas nuevas
#   - al final borra SOLO lo de la réplica (contenedores, redes, su volumen, su imagen y la carpeta)
# Usa los certificados que ya hay en /etc/ssl (guía §2). Uso: bash scripts/prueba-replica-vm.sh 2>&1 | tee ~/prueba-replica.txt

DIR=$HOME/opsmatrix-replica
P=opsmatrix-replica
D=portal.opsmatrix.test
CA=/etc/ssl/mf0489/ca.crt

echo "===== 1. CLON LIMPIO DE GITHUB ====="
date -u
rm -rf "$DIR"
git clone -q https://github.com/margalefxr/opsmatrix-lab.git "$DIR" || exit 1
cd "$DIR" || exit 1
git log --oneline -1
ls -a | tr '\n' ' '; echo
[ -f .env ] && echo "ALERTA: el clon trae .env" || echo "OK: el clon no trae .env"

echo
echo "===== 2. SOLO PARA LA PRUEBA: otro proyecto y otros puertos ====="
# Sin esto chocaría con el despliegue real (mismos nombres de contenedor y puertos 80/443)
cat > docker-compose.override.yml <<'EOF'
services:
  reverse-proxy:
    container_name: !reset null
    ports: !override
      - "127.0.0.1:8080:80"
      - "127.0.0.1:8443:443"
  app:
    container_name: !reset null
  db:
    container_name: !reset null
EOF
cat docker-compose.override.yml
[ "$(docker compose config | sed -n 's/^name: //p')" = "$P" ] || { echo "ALERTA: el proyecto no es $P, paro"; exit 1; }
echo "OK: proyecto $P (el real es opsmatrix-lab y no se toca)"

echo
echo "===== 3. deploy.sh TAL CUAL ====="
bash scripts/deploy.sh

echo
echo "===== 4. ¿FUNCIONA? (la BBDD es nueva: tarda unos segundos en arrancar la primera vez) ====="
# Espero a la BBDD (no a la web: cada visita a / suma una fila y estropearía la cuenta)
for _ in $(seq 1 30); do
  docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" -e "SELECT 1"' >/dev/null 2>&1 && break
  sleep 2
done
sleep 5   # la primera vez MariaDB arranca, crea el usuario y se reinicia: margen para ese reinicio
echo "-- HTTPS con la CA (2 visitas: tiene que salir 1 y luego 2)"
for _ in 1 2; do
  curl -s -w "\ncodigo=%{http_code} tls=%{ssl_verify_result}\n" --cacert $CA --resolve $D:8443:127.0.0.1 https://$D:8443/
done
echo "-- HTTP -> HTTPS"
curl -sI --resolve $D:8080:127.0.0.1 http://$D:8080/prueba | grep -iE "^HTTP|^Location"
echo "-- sin la CA (tiene que fallar, exit 60)"
curl -s -o /dev/null --resolve $D:8443:127.0.0.1 https://$D:8443/; echo "exit $?"
echo "-- openssl"
openssl s_client -connect 127.0.0.1:8443 -servername $D -CAfile $CA -verify_hostname $D -verify_return_error -brief </dev/null 2>&1 | grep -E "Protocol|Verification|peername"
echo "-- la BBDD nueva guarda las visitas"
docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT COUNT(*) AS visitas FROM visitas"'
echo "-- aislamiento"
docker compose exec -T reverse-proxy getent hosts app >/dev/null && echo "control OK: el proxy resuelve app"
docker compose exec -T reverse-proxy getent hosts db || echo "OK: el proxy no ve la BBDD"
docker compose exec -T app id

echo
echo "===== 5. LIMPIEZA: solo lo de la réplica ====="
docker compose down
docker volume rm ${P}_mariadb_data
docker image rm ${P}-app >/dev/null && echo "imagen ${P}-app borrada"
cd "$HOME" && rm -rf "$DIR"
echo "-- lo que queda (el despliegue real tiene que seguir igual)"
docker ps --format "{{.Names}} {{.Status}}"
docker volume ls --format "{{.Name}}"
ls -d "$DIR" 2>/dev/null || echo "OK: carpeta de la réplica borrada"

echo
echo "===== FIN ====="
