# WORKLOG — ExP 89 (MF0489)

Rama `mf0489-https`, ya unida a `main`. Trabajo hecho del 19 al 21/10/2026 entre el Mac (CA y cliente) y la VM Ubuntu (servidor).

| # | Paso | Resultado |
|---|---|---|
| 1 | Fase 1: rediseño de la arquitectura con HTTPS | [fase1-arquitectura.md](fase1-arquitectura.md) |
| 2 | Fase 2: CA en el Mac, CSR en la VM, firma e instalación en `/etc/ssl/` | `servidor.crt: OK`. [fase2-pki.md](fase2-pki.md) |
| 3 | Revisión de cómo estaba la VM (Actividad 8) | BBDD en bucle sin `.env`, Nginx por defecto, compose con contraseñas |
| 4 | Copia del volumen y `docker compose down` (sin `-v`) | Volumen vacío (131 bytes) |
| 5 | Compose nuevo, Nginx, app Flask y `.env.example`, probados primero en local | `nginx -t` OK, 301, TLS 1.3. [prueba-local.txt](evidencias/fase3/prueba-local.txt) |
| 6 | Paso de la rama a la VM con `git bundle` (sin subir a GitHub) | Rama en la VM |
| 7 | `.env` con `openssl rand`, `docker compose up -d --build` | Los 3 contenedores `Up`. [`env-creado.txt`](evidencias/fase3/env-creado.txt) |
| 8 | Pruebas desde el Mac y reinicio para ver si se guardan los datos | Todo OK. [fase3-https-docker.md](fase3-https-docker.md) |
| 9 | Revisión completa con `scripts/check-mac.sh` y `scripts/check-vm.sh` | Encontró un `ca.key` viejo en la VM, borrado |
| 10 | Fase 4: log de Nginx con TLS, regla Suricata 1000003, pruebas TLS, tcpdump y correlación | TLS 1.1 rechazado, ruta invisible en el 443, mismo puerto en las 3 fuentes. [fase4-auditoria-tls-monitorizacion.md](fase4-auditoria-tls-monitorizacion.md) |
| 11 | Fase 5: SSH solo con clave, limpieza del firewall viejo y las redes `docker_*`, copia de la BBDD probada | `Permission denied (publickey)` con contraseña, restaurada con 9 de 9 filas |
| 12 | Reinicio de la VM y revisión final con `check-vm.sh` y `check-mac.sh` | Todo vuelve solo. [fase5-entrega-final.md](fase5-entrega-final.md) |
| 13 | Extra: `pip-audit`, SBOM y `detect-secrets` | CVE en Flask 3.0.3: no explotable aquí, actualizado igual a 3.1.3 y dependencias fijadas. [extras.md](extras.md#1-software-de-terceros-cve-de-flask) |
| 14 | Extra: revocación con CRL e inventario criptográfico | Revocado → `error 23`, real → `OK`. SSH aún sin post-cuántica. [extras.md](extras.md) |
| 15 | Revisión final con herramientas: `shellcheck`, `pyflakes`, `docker compose config`, `nginx -t`, `suricata -T`, `sshd -t`, OpenSSL y enlaces | Sin errores. [validacion-herramientas.txt](evidencias/fase5/validacion-herramientas.txt) |
| 16 | CI con GitHub Actions y justificación HTTP/HTTPS en la Fase 1 | Las comprobaciones de la Fase 5 se repiten solas en cada push |
| 17 | Evidencias pedidas en el feedback del MF0488: ping, SID 1000001, `suricata -T`, `HOME_NET` y línea base de actividad | Todo real. [Fase 4](fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| 18 | Subida a GitHub y comprobación desde un clon limpio: `check-vm.sh` en la VM (en `main`) y `check-mac.sh` en el Mac | Igual que antes de subir. [`check-vm-github.txt`](evidencias/fase5/check-vm-github.txt) y [`check-mac-github.txt`](evidencias/fase5/check-mac-github.txt) |
| 19 | Revisión cruzada: cada salida de los docs buscada en las evidencias y cada directiva en el código | 44 OK. Las salidas que solo estaban en mi terminal ahora están en `evidencias/`. [`coherencia-docs-codigo.txt`](evidencias/fase5/coherencia-docs-codigo.txt) |
| 20 | Revisión de todo el repo, también lo del MF0488 | Tabla de [correcciones del MF0488](../correcciones-mf0488.md), banner en cada documento antiguo, bug de `check_baseline.sh` corregido, carpetas vacías borradas y `shellcheck` de todos los `.sh` en la CI |
| 21 | Controles positivos en `check-vm.sh`: cada prueba que tiene que fallar, con otra que demuestra que el comando funciona | El proxy resuelve `app` pero no `db`. La app sale (`rc=0`) y la BBDD no (`rc=1`, sin ruta por defecto). [`check-vm-controles.txt`](evidencias/fase5/check-vm-controles.txt) |
| 22 | `deploy.sh` en la VM y arranques de la VM | `[OK] Desplegado`, `.env` sin tocar, BBDD sin recrear. Arranque actual: 20/10 09:40:25 UTC. [`deploy-vm.txt`](evidencias/fase5/deploy-vm.txt), [`arranques.txt`](evidencias/fase5/arranques.txt) |

## Dificultades

| # | Fase | Dificultad | Solución |
|---|---|---|---|
| 1 | 2 | `Permission denied` al leer `/etc/ssl/mf0489/ca.crt` aunque tenía 644 | La carpeta se creó con 700 por el `umask 077` de la sesión. `sudo chmod 755 /etc/ssl/mf0489` |
| 2 | 2 | El `.gitignore` viejo no dejaba subir `*.crt` | Lo cambié para excluir solo claves y secretos. Los certificados son públicos |
| 3 | 2 | Había restos de la PKI del MF0488 en el repo (`ca.srl`, `server.csr`) | Borrados |
| 4 | 2 | `scp` me pidió contraseña aunque el README dice "solo Ed25519" | Resuelto en la Fase 5 (ver 16) |
| 5 | 3 | La BBDD llevaba semanas reiniciándose | No había `.env` y los nombres de variables no coincidían. Arreglado el `.env.example` y creado el `.env` |
| 6 | 3 | El Nginx que había cortaba la conexión | Tenía la config por defecto. Lo sustituí por el reverse proxy |
| 7 | 3 | `pip install` sin internet al construir la app | `docker0` sin IP. `sudo systemctl restart docker` |
| 8 | 3 | La app no arrancaba: `Permission denied` en `app.py` | `umask 077` → archivo 600 → `nobody` no lo lee. `RUN chmod 644` en el Dockerfile |
| 9 | 3 | Nginx: `host not found in upstream "app"` | Efecto de la 8. Se arregló solo |
| 10 | 3 | El puerto 80 enseñaba la versión de Nginx | `server_tokens off` también en el bloque del 80 |
| 11 | 3 | `ca.key` y `server.key` del MF0488 en la VM | Hash distinto al de la CA nueva y nunca subidos a git. Borrados con `shred -u` para que no acaben en la OVA del CTF |
| 12 | 4 | Las reglas activas de Suricata no eran las del repo | El repo es ahora copia exacta de las activas + la nueva |
| 13 | 4 | La regla 1000003 no saltaba con `flags:S` | El Mac manda el SYN con bits ECN. `flags:S,CE`, probado antes en local con Suricata |
| 14 | 4 | Alertas duplicadas | Suricata arrancaba con `--af-packet -i enp2s0` (dos capturas). Override de systemd solo con `--af-packet` |
| 15 | 4 | `tcpdump` del 80 casi vacío | Leí el archivo antes de que tcpdump lo escribiera. Esperar al `timeout` o usar `-l` |
| 16 | 5 | `authorized_keys` vacío: nunca hubo una clave autorizada | `ssh-copy-id`, comprobar y solo entonces `00-opsmatrix.conf` (gana a `50-cloud-init.conf`) |
| 17 | 5 | `rules.v4` solo tenía reglas viejas de Docker | Copia en `~/backups/`, `netfilter-persistent` desactivado y reinicio |
| 18 | 5 | `deploy.sh` y README desactualizados | Reescritos |
| 19 | Extra | `pip-audit` encontró CVE-2026-27205 en Flask 3.0.3 | No explotable aquí (sin `session` ni caché). Subido a 3.1.3, todas las dependencias fijadas, probado en local y reconstruido en la VM |
| 20 | Extra | En la prueba local, `openssl ca` dio `Serial number … has already been issued` | `ca.srl` guarda el último serial usado por `openssl x509`, pero `openssl ca` lo lee como el siguiente. Uso `rand_serial = yes` |
| 21 | CI | La primera ejecución en GitHub falló en `detect-secrets` | Con `--all-files` escaneaba el `.env` que crea el paso anterior a partir de `.env.example`. Ahora solo mira los archivos versionados en git. Reproducido en local: [`ci.txt`](evidencias/fase5/ci.txt) |
| 22 | Entrega | En GitHub se veían carpetas vacías `config/`, `docker/` y `suricata/` en la raíz (solo un `.gitkeep` del MF0488). La de `suricata/` podía hacer pensar que faltaban las reglas | Borradas. Las reglas están en `layer1-telemetry/suricata/rules/` (tabla de equivalencias en el README) |
| 23 | — | Al copiar comandos se colaba `\;` y alguna vez lancé un bloque en la máquina equivocada | Comandos sin `;` y, al final, scripts en vez de copiar y pegar |
| 24 | Entrega | En la revisión final vi que algunas salidas citadas en los docs (Fase 2, Actividad 8, tcpdump del 80, primer intento de la Fase 4) estaban en mi terminal pero no en el repo | Copiadas a `evidencias/`. Lo que no pude enseñar con una salida de la VM lo reproduje en local y lo digo (regla ICMP, montaje de `default.conf`) |
| 25 | Entrega | Las pruebas que tienen que fallar (proxy → BBDD, BBDD → internet) decían "OK" también si fallaba el comando. Y mi primer control tenía su propio fallo: `sh` en la imagen de MariaDB es `dash`, y `command -v bash timeout` solo mira el primer nombre | Control positivo para cada una, código de salida real y tabla de rutas. Los dos intentos están en `evidencias/fase5/` |

## Pendiente (mejoras)

| Qué | Motivo |
|---|---|
| Firewall de host con nftables | Hoy depende de lo que publica Docker |
| Cortar la salida a internet de la app | Sale y no lo necesita (`frontend_net` no puede ser `internal`) |
| Actualizaciones de Ubuntu pendientes | Gestión de parches |
| Renovar `servidor.crt` antes del 19/10/2027 | Caduca |
| Regenerar `ca.crl` antes del 19/11/2026 y añadir `crlDistributionPoints` | Si caduca, los clientes que la comprueban fallan |
| Cifrar las copias de la BBDD | Hoy solo tienen permisos 600 |
| SSH con intercambio post-cuántico | El servidor lo soporta; falta el cliente |
