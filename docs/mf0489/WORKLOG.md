# WORKLOG — ExP 89 (MF0489)

Rama `mf0489-https`. Trabajo hecho el 19 y 20/10/2026 entre el Mac (CA y cliente) y la VM Ubuntu (servidor).

| # | Paso | Resultado |
|---|---|---|
| 1 | Fase 1: rediseño de la arquitectura con HTTPS | [fase1-arquitectura.md](fase1-arquitectura.md) |
| 2 | Fase 2: CA en el Mac, CSR en la VM, firma e instalación en `/etc/ssl/` | `servidor.crt: OK`. [fase2-pki.md](fase2-pki.md) |
| 3 | Revisión de cómo estaba la VM (Actividad 8) | BBDD en bucle sin `.env`, Nginx por defecto, compose con contraseñas |
| 4 | Copia del volumen y `docker compose down` (sin `-v`) | Volumen vacío (131 bytes) |
| 5 | Compose nuevo, Nginx, app Flask y `.env.example`, probados primero en local | `nginx -t` OK, 301, TLS 1.3 |
| 6 | Paso de la rama a la VM con `git bundle` (sin subir a GitHub) | Rama en la VM |
| 7 | `.env` con `openssl rand`, `docker compose up -d --build` | Los 3 contenedores `Up` |
| 8 | Pruebas desde el Mac y reinicio para ver si se guardan los datos | Todo OK. [fase3-https-docker.md](fase3-https-docker.md) |
| 9 | Revisión completa con `scripts/check-mac.sh` y `scripts/check-vm.sh` | Encontró un `ca.key` viejo en la VM, borrado |
| 10 | Fase 4: log de Nginx con TLS, regla Suricata 1000003, pruebas TLS, tcpdump y correlación | TLS 1.1 rechazado, ruta invisible en el 443, mismo puerto en las 3 fuentes. [fase4-auditoria-tls-monitorizacion.md](fase4-auditoria-tls-monitorizacion.md) |
| 11 | Fase 5: SSH solo con clave, limpieza del firewall viejo y las redes `docker_*`, copia de la BBDD probada | `Permission denied (publickey)` con contraseña, restaurada con 9 de 9 filas |
| 12 | Reinicio de la VM y revisión final con `check-vm.sh` y `check-mac.sh` | Todo vuelve solo. [fase5-entrega-final.md](fase5-entrega-final.md) |
| 13 | Extra: `pip-audit`, SBOM y `detect-secrets` | CVE en Flask 3.0.3 → 3.1.3 y dependencias fijadas. [supply-chain.txt](evidencias/supply-chain.txt) |

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
| 20 | — | Al copiar comandos se colaba `\;` y alguna vez lancé un bloque en la máquina equivocada | Comandos sin `;` y, al final, scripts en vez de copiar y pegar |

## Pendiente (mejoras)

| Qué | Motivo |
|---|---|
| Firewall de host con nftables | Hoy depende de lo que publica Docker |
| Actualizaciones de Ubuntu pendientes | Gestión de parches |
| Renovar `servidor.crt` antes del 19/10/2027 | Caduca |
