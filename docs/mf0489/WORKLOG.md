# WORKLOG — ExP 89 (MF0489)

Rama `mf0489-https`, ya unida a `main`. Lo trabajé del 19 al 22/10/2026 entre el Mac (CA y cliente) y la VM Ubuntu (servidor).

| # | Paso | Resultado |
|---|---|---|
| 1 | Rediseño la arquitectura para meter HTTPS (Fase 1) | [fase1-arquitectura.md](fase1-arquitectura.md) |
| 2 | Monto la CA en el Mac, genero la CSR en la VM, la firmo e instalo en `/etc/ssl/` (Fase 2) | `servidor.crt: OK`. [fase2-pki.md](fase2-pki.md) |
| 3 | Miro cómo estaba la VM (Actividad 8) | La BBDD en bucle sin `.env`, Nginx por defecto y el compose con contraseñas dentro |
| 4 | Copio el volumen y hago `docker compose down` (sin `-v`) | El volumen estaba vacío (131 bytes) |
| 5 | Monto el compose nuevo, Nginx, la app Flask y el `.env.example`, y lo pruebo primero en local | `nginx -t` OK, 301, TLS 1.3. [prueba-local.txt](evidencias/fase3/prueba-local.txt) |
| 6 | Llevo la rama a la VM con `git bundle` (sin subirla a GitHub) | La rama ya en la VM |
| 7 | Creo el `.env` con `openssl rand` y hago `docker compose up -d --build` | Los 3 contenedores `Up`. [`env-creado.txt`](evidencias/fase3/env-creado.txt) |
| 8 | Pruebo desde el Mac y reinicio para ver si se guardan los datos | Todo OK. [fase3-https-docker.md](fase3-https-docker.md) |
| 9 | Reviso todo con `scripts/check-mac.sh` y `scripts/check-vm.sh` | Me encontré un `ca.key` viejo en la VM y lo borré |
| 10 | Fase 4: log de Nginx con TLS, regla de Suricata 1000003, pruebas TLS, tcpdump y correlación | TLS 1.1 rechazado, la ruta no se ve en el 443 y el mismo puerto en las 3 fuentes. [fase4-auditoria-tls-monitorizacion.md](fase4-auditoria-tls-monitorizacion.md) |
| 11 | Fase 5: SSH solo con clave, limpio el firewall viejo y las redes `docker_*`, y pruebo la copia de la BBDD | Con contraseña da `Permission denied (publickey)`, y la copia se restaura con 9 de 9 filas |
| 12 | Reinicio la VM y hago la revisión final con `check-vm.sh` y `check-mac.sh` | Vuelve todo solo. [fase5-entrega-final.md](fase5-entrega-final.md) |
| 13 | Extra: `pip-audit`, SBOM y `detect-secrets` | CVE en Flask 3.0.3: aquí no se podía explotar, pero actualicé igual a 3.1.3 y fijé las dependencias. [extras.md](extras.md#1-software-de-terceros-cve-de-flask) |
| 14 | Extra: revocación con CRL e inventario de claves | Revocado → `error 23`, el real → `OK`. SSH todavía sin post-cuántica. [extras.md](extras.md) |
| 15 | Reviso con herramientas: `shellcheck`, `pyflakes`, `docker compose config`, `nginx -t`, `suricata -T`, `sshd -T`, OpenSSL y los enlaces | Sin errores. [validacion-herramientas.txt](evidencias/fase5/validacion-herramientas.txt) |
| 16 | Monto la CI con GitHub Actions y justifico HTTP/HTTPS en la Fase 1 | Las comprobaciones de la Fase 5 se repiten solas en cada push |
| 17 | Saco las evidencias que me pidieron en el feedback del MF0488: ping, SID 1000001, `suricata -T`, `HOME_NET` y línea base de actividad | Todo real. [Fase 4](fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| 18 | Subo a GitHub y lo compruebo desde un clon limpio: `check-vm.sh` en la VM (en `main`) y `check-mac.sh` en el Mac | Igual que antes de subir. [`check-vm-github.txt`](evidencias/fase5/check-vm-github.txt) y [`check-mac-github.txt`](evidencias/fase5/check-mac-github.txt) |
| 19 | Comparo cada salida que pongo en los docs con las evidencias, y cada directiva con el código | 44 OK. Algunas salidas solo las tenía en la terminal y las pasé a `evidencias/`. [`coherencia-docs-codigo.txt`](evidencias/fase5/coherencia-docs-codigo.txt) |
| 20 | Repaso todo el repo, también lo del MF0488 | Apunto en [correcciones del MF0488](../correcciones-mf0488.md) lo que ya no es verdad y pongo un aviso en cada documento antiguo. Arreglo un fallo de `check_baseline.sh`, borro carpetas vacías y hago que la CI pase `shellcheck` a todos los `.sh` |
| 21 | Añado controles positivos a `check-vm.sh`: cada prueba que tiene que fallar, con otra que demuestra que el comando funciona | El proxy resuelve `app` pero no `db`. La app sale (`rc=0`) y la BBDD no (`rc=1`, sin ruta por defecto). [`check-vm-controles.txt`](evidencias/fase5/check-vm-controles.txt) |
| 22 | Pruebo `deploy.sh` en la VM y miro los arranques | `[OK] Desplegado`, sin tocar el `.env` ni recrear la BBDD. Arranque actual: 20/10 09:40:25 UTC. [`deploy-vm.txt`](evidencias/fase5/deploy-vm.txt), [`arranques.txt`](evidencias/fase5/arranques.txt) |
| 23 | Repaso con el enunciado y la rúbrica | Añado la comparación de la huella del certificado que entrega Nginx con el emitido (F3.2): son iguales. Listo los volúmenes que no usa nadie (10) y compruebo con `reflog` que el clon del Mac viene de GitHub. [`check-mac-final2.txt`](evidencias/fase5/check-mac-final2.txt), [`check-vm-final2.txt`](evidencias/fase5/check-vm-final2.txt), [`clon-mac.txt`](evidencias/fase5/clon-mac.txt) |
| 24 | Borro los 8 volúmenes anónimos del MF0488 (`docker volume prune`, sin `-a`) | Quedan la BBDD de OpsMatrix y los 2 de `infra-lab`. [`volumenes-limpieza.txt`](evidencias/fase5/volumenes-limpieza.txt) |
| 25 | Monto la PKI con una CA y claves nuevas desde un clon limpio, siguiendo solo la guía | La PKI nueva funciona, `deploy.sh` crea el `.env` y `check-mac.sh` sale bien. En el entorno de pruebas no hay Docker Hub, así que los contenedores los pruebo en el paso 26. [`replica-desde-cero.txt`](evidencias/fase5/replica-desde-cero.txt) |
| 26 | Despliego desde cero en la VM: clon limpio, `deploy.sh`, `.env` y BBDD nuevos | Todo OK y las visitas empiezan en 1. Luego vuelvo al despliegue de siempre y sigue con sus datos (la primera visita es del 19/10). [`prueba-limpia-vm.txt`](evidencias/fase5/prueba-limpia-vm.txt), [`prueba-limpia-mac.txt`](evidencias/fase5/prueba-limpia-mac.txt) |
| 27 | Me leo el repo entero como si fuera otra persona que lo descarga | Añado a la guía los pasos de Suricata para una instalación nueva, meto las evidencias que faltaban (aviso de Flask, hashes del `ca.key` viejo) y quito frases que decían más de lo que había probado. [`suricata-desde-cero.txt`](evidencias/fase5/suricata-desde-cero.txt) |
| 28 | Valido las defensas desde Kali (172.16.181.128), sin mi CA | Solo responden 22/80/443, la BBDD y la app no se alcanzan, el HTTPS sin CA falla (`exit 60`), TLS 1.0/1.1 rechazado, y Suricata lo caza con la IP de Kali. [validacion-ofensiva.md](validacion-ofensiva.md) |

## Dificultades

| # | Fase | Qué me pasó | Cómo lo resolví |
|---|---|---|---|
| 1 | 2 | `Permission denied` al leer `/etc/ssl/mf0489/ca.crt` aunque tenía 644 | La carpeta se había creado con 700 por el `umask 077` de la sesión. La dejé en 755 con `sudo chmod 755 /etc/ssl/mf0489` |
| 2 | 2 | El `.gitignore` viejo no me dejaba subir los `*.crt` | Lo cambié para excluir solo claves y secretos: los certificados son públicos |
| 3 | 2 | Había restos de la PKI del MF0488 en el repo (`ca.srl`, `server.csr`) | Los borré |
| 4 | 2 | `scp` me pidió contraseña aunque el README decía "solo Ed25519" | Lo dejé resuelto en la Fase 5 (ver paso 16) |
| 5 | 3 | La BBDD llevaba semanas reiniciándose | No había `.env` y los nombres de las variables no coincidían. Arreglé el `.env.example` y creé el `.env` |
| 6 | 3 | El Nginx que había cortaba la conexión | Tenía la config por defecto. Lo sustituí por el reverse proxy |
| 7 | 3 | `pip install` sin internet al construir la app | `docker0` se había quedado sin IP. Lo arreglé con `sudo systemctl restart docker` |
| 8 | 3 | La app no arrancaba: `Permission denied` en `app.py` | `umask 077` → el archivo salía 600 → `nobody` no lo leía. Puse `RUN chmod 644` en el Dockerfile |
| 9 | 3 | Nginx: `host not found in upstream "app"` | Era por lo de la 8. Se arregló solo cuando arreglé la app |
| 10 | 3 | El puerto 80 enseñaba la versión de Nginx | Puse `server_tokens off` también en el bloque del 80 |
| 11 | 3 | `ca.key` y `server.key` del MF0488 en la VM | Tenían un hash distinto al de la CA nueva y no estaban en git. Los borré con `shred -u` para que no acaben en la OVA del CTF |
| 12 | 4 | Las reglas de Suricata cargadas no eran las del repo | Puse en el repo las que de verdad estaban cargadas más la nueva |
| 13 | 4 | La regla 1000003 no saltaba con `flags:S` | El Mac manda el SYN con bits ECN. Lo cambié a `flags:S,CE` y lo probé antes en local con Suricata |
| 14 | 4 | Las alertas salían duplicadas | Suricata arrancaba con `--af-packet -i enp2s0` (dos capturas). Lo arreglé con un override de systemd que solo lleva `--af-packet` |
| 15 | 4 | El `tcpdump` del 80 salía casi vacío | Había leído el archivo antes de que tcpdump lo escribiera. Hay que esperar al `timeout` o usar `-l` |
| 16 | 5 | `authorized_keys` estaba vacío: nunca había autorizado una clave | Hice `ssh-copy-id`, comprobé que entraba, y solo entonces instalé `00-opsmatrix.conf` (gana a `50-cloud-init.conf`) |
| 17 | 5 | `rules.v4` solo tenía reglas viejas de Docker | Guardé una copia en `~/backups/`, desactivé `netfilter-persistent` y reinicié |
| 18 | 5 | `deploy.sh` y el README estaban desactualizados | Los reescribí |
| 19 | Extra | `pip-audit` encontró el CVE-2026-27205 en Flask 3.0.3 | Aquí no se podía explotar (sin `session` ni caché). Subí a 3.1.3, fijé todas las dependencias, lo probé en local y reconstruí la app en la VM |
| 20 | Extra | En la prueba local, `openssl ca` me dio `Serial number … has already been issued` | `ca.srl` guarda el último serial que usó `openssl x509`, pero `openssl ca` lo lee como el siguiente. Lo arreglé con `rand_serial = yes` |
| 21 | CI | La primera ejecución en GitHub falló en `detect-secrets` | Con `--all-files` escaneaba el `.env` que crea el paso anterior a partir de `.env.example`. Lo dejé mirando solo los archivos versionados en git. Lo reproduje en local: [`ci.txt`](evidencias/fase5/ci.txt) |
| 22 | Entrega | En GitHub se veían carpetas vacías `config/`, `docker/` y `suricata/` en la raíz (solo un `.gitkeep` del MF0488), y la de `suricata/` podía hacer pensar que faltaban las reglas | Las borré. Las reglas están en `layer1-telemetry/suricata/rules/` (tabla de equivalencias en el README) |
| 23 | — | Al copiar comandos se me colaba algún `\;` y alguna vez lancé un bloque en la máquina equivocada | Dejé los comandos sin `;` y, al final, usé scripts en vez de copiar y pegar |
| 24 | Entrega | Repasando vi que algunas salidas que citaba en los docs (Fase 2, Actividad 8, tcpdump del 80, primer intento de la Fase 4) las tenía en la terminal pero no en el repo | Las copié a `evidencias/`. Lo que no podía enseñar con una salida de la VM lo reproduje en local y lo digo (regla ICMP, montaje de `default.conf`) |
| 25 | Entrega | Las pruebas que tienen que fallar (proxy → BBDD, BBDD → internet) daban "OK" también si fallaba el propio comando. Y mi primer control también falló: en la imagen de MariaDB `sh` es `dash` ([intento 1](evidencias/fase5/check-vm-controles-intento1.txt)) | Le puse un control positivo a cada una, el código de salida real y la tabla de rutas ([`check-vm-controles.txt`](evidencias/fase5/check-vm-controles.txt)) |
| 26 | Entrega | La guía decía "comandos en la Fase 2", pero ahí faltaban los `mkdir` de la CA y de `/etc/ssl/mf0489`, los `scp` y de dónde sacar `servidor.ext`. Otra persona se habría quedado atascada en el primer comando | Escribí el procedimiento completo en la guía §2 y lo probé tal cual desde un clon limpio |
| 27 | Entrega | Con el `suricata.yaml` que trae Ubuntu (escucha en `eth0` y no carga `local.rules`) mis reglas no se cargan, y `suricata -T` da OK igualmente. En mi VM no me pasaba porque eso ya lo había cambiado en el MF0488 | Lo puse en la guía §3: cambiar la interfaz, añadir `- local.rules` y comprobarlo con un ping que tiene que dar alerta |

## Pendiente (mejoras)

| Qué | Motivo |
|---|---|
| Firewall de host con nftables | Hoy depende de lo que publica Docker |
| Cortar la salida a internet de la app | Sale y no lo necesita (`frontend_net` no puede ser `internal`) |
| Volúmenes de `infra-lab` sin usar (2) | Decidir si van en la OVA del CTF |
| Aplicar las actualizaciones de Ubuntu pendientes | Gestión de parches |
| Renovar `servidor.crt` antes del 19/10/2027 | Caduca |
| Regenerar `ca.crl` antes del 19/11/2026 y añadir `crlDistributionPoints` | Si caduca, los clientes que la comprueban fallan |
| Cifrar las copias de la BBDD | Hoy solo tienen permisos 600 |
| SSH con intercambio post-cuántico | El servidor lo soporta; me falta el cliente |
