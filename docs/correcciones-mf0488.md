# Lo del MF0488 que ya no es verdad (o que no pude demostrar)

Los documentos del MF0488 (`ARCHITECTURE.md`, `docs/adr/`, `docs/WORKLOG.md`, `docs/architecture-schema.md`, `docs/architecture/`, `docs/assets/` y los `.excalidraw`) los he dejado tal y como los entregué, porque son lo que se corrigió entonces. Pero al revisarlos para el MF0489 vi cosas que ya no son así, o que en su día escribí sin poder demostrarlas. Las apunto aquí con cómo están ahora y dónde está la prueba. **Si algo no coincide, lo que vale es lo del MF0489.**

## Documentos

| Dónde | Qué decía | Cómo está ahora | Evidencia |
|---|---|---|---|
| README antiguo, `architecture-schema.md`, ADR-0006 | "Solo TLS 1.3" | TLS 1.2 y 1.3. El 1.1 lo rechaza | [Fase 4 §3](mf0489/fase4-auditoria-tls-monitorizacion.md#3-versiones-tls), [`check-mac-github.txt`](mf0489/evidencias/fase5/check-mac-github.txt) §8 |
| ADR-0006 | Certificados autofirmados RSA 2048 | Una CA mía RSA 4096 (fuera de la VM) y el certificado del servidor RSA 3072 firmado por ella | [Fase 2](mf0489/fase2-pki.md) |
| ADR-0001, ADR-0002, `docs/WORKLOG.md` | Ubuntu Server 24.04 LTS | La VM es Ubuntu 26.04 LTS | [`fase5-ssh-firewall-backup.txt`](mf0489/evidencias/fase5/fase5-ssh-firewall-backup.txt) (al final) |
| ADR-0001 | "La única forma de llegar a la BBDD es a través de Nginx" y "los intentos de acceso quedan en los logs de Nginx" | Al revés: Nginx **no** está en `backend_net` y ni siquiera resuelve `db` (`app` sí). Con MariaDB solo habla la app | [`check-vm-controles.txt`](mf0489/evidencias/fase5/check-vm-controles.txt) §9 y §10 |
| ADR-0001, README antiguo | WAF | No hay WAF. Nginx solo hace de reverse proxy | [`default.conf`](../layer2-perimeter/nginx/default.conf) |
| ADR-0001 | `internal: true` funciona con reglas en la cadena `DOCKER-USER` | Las reglas de iptables no las he revisado. Lo que sí he comprobado es el efecto: la BBDD no tiene ruta por defecto y no sale a internet, y la app sí | [`check-vm-controles.txt`](mf0489/evidencias/fase5/check-vm-controles.txt) §10 |
| ADR-0002 | Suricata detecta escaneos Nmap y captura con eBPF | Ninguna regla busca Nmap, y captura con `af-packet`, sin eBPF | [`local.rules`](../layer1-telemetry/suricata/rules/local.rules), [`suricata-config.txt`](mf0489/evidencias/fase4/suricata-config.txt) |
| ADR-0004 | 1000001 = ICMP Echo Request. 1000002 = user-agent de Nmap, Nikto o sqlmap | La 1000001 salta con **cualquier** ICMP (también con IPv6 tipo 133) y la 1000002 con cualquier conexión TCP al 80, sin mirar el user-agent. Las de Nmap estaban en el repo, pero las que estaban cargadas en la VM eran otras | [`fase4-intento1-vm.txt`](mf0489/evidencias/fase4/fase4-intento1-vm.txt), [`feedback-mf0488.txt`](mf0489/evidencias/fase4/feedback-mf0488.txt) |
| ADR-0005 | Un hook `pre-commit` actualiza el WORKLOG. "Trazabilidad 100% garantizada" | El hook lo tuve en local: los commits `48a7879` y `fc6c42e` del 15/09 cambian el WORKLOG y en el mensaje pone que estaba probando el hook. Pero git no sube los hooks, así que quien clone el repo no lo tiene, y eso de "garantizada" no se sostiene. El WORKLOG del MF0489 lo he hecho a mano | `git show 48a7879 --stat` |
| ADR-0003 | Numeración ADR-000, 001 y 003 dentro de un mismo archivo | Choca con los archivos `0001`…`0007`. Lo dejo como estaba | — |
| ADR-0003 | OpsMatrix es una fintech | Es el portal de una gestoría (README) | — |
| `docs/WORKLOG.md` (sesión 3) | MariaDB 11.4, contenedores `(healthy)`, redes `docker_backend_net` y `docker_frontend_net` | `mariadb:10.11`, sin `healthcheck` en el compose y con las redes `opsmatrix-lab_frontend_net` y `opsmatrix-lab_backend_net`. Las `docker_*` las borré en la Fase 5 | [`docker-compose.yml`](../docker-compose.yml), [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §7, §9 y §13 |
| ADR-0007 | Persistencia con bind mounts | Es un volumen con nombre, `mariadb_data` | [Fase 3 §7](mf0489/fase3-https-docker.md#7-app-y-persistencia) |
| ADR-0007 | AppArmor y OrbStack | AppArmor no lo he configurado ni comprobado. Y las pruebas en local del MF0489 no las hice en OrbStack | — |
| `architecture-schema.md` | El contenedor `opsmatrix_web` en las dos redes | `reverse-proxy` solo está en `frontend_net`. La que está en las dos es `app` | [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §9 |
| `docs/architecture/00-documentation-framework.md` | El `.gitignore` bloquea los `.crt` | Los certificados son públicos y los he subido a `layer2-perimeter/pki/`. Lo que bloqueo son claves, `.env` y copias | [`.gitignore`](../.gitignore) |
| `docs/architecture/00-documentation-framework.md` | Conventional Commits y entregables en HTML5 | Mis commits del MF0489 no siguen Conventional Commits (casi todos empiezan por `MF0489`). Y entregables en HTML no hay | `git log` |
| `docs/assets/README.md` | Los diagramas se ven en `ARCHITECTURE.md` | `ARCHITECTURE.md` no tiene imágenes. El diagrama de ahora es [`arquitectura-final.png`](mf0489/arquitectura-final.png) | — |
| `architecture.excalidraw`, `architecture-master.excalidraw`, `assets/architecture-schema.png` | Los diagramas del MF0488 | Los he sustituido por [`arquitectura-final.mmd`](mf0489/arquitectura-final.mmd) | — |

## Scripts y carpetas

| Qué | Problema | Qué he hecho |
|---|---|---|
| `scripts/sync_ops.sh` | Hace `git add .` y `git push origin main` sin revisar lo que sube | En el MF0489 no lo he usado: subo a mano después de revisar, y la CI lo vuelve a comprobar. Lo he marcado en su cabecera |
| `layer1-telemetry/scripts/log_work.sh` y `capture_debug.sh` | Escriben en el `docs/WORKLOG.md` del MF0488 | Tampoco los he usado en el MF0489. Los he marcado en su cabecera |
| `layer1-telemetry/baseline/check_baseline.sh` | Con 0 alertas escribía `0` dos veces (`grep -c` ya escribe 0 y después `\|\| echo "0"` añade otro) | Lo he arreglado con `\|\| true`. Esta es una línea base de salud; la de actividad está en la [Fase 4](mf0489/fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| Carpetas `layer2-perimeter/diffie-hellman/` y `layer3-services/nginx/conf.d/` | Estaban vacías (solo un `.gitkeep`) y daban a entender que ahí había parámetros DH o una config de Nginx | Las he borrado. Nginx no usa `ssl_dhparam`: en TLS 1.2 negocia ECDHE ([`fase4-mac.txt`](mf0489/evidencias/fase4/fase4-mac.txt)) |
| `.gitkeep` en carpetas que ya tienen archivos | Sobraban | Borrados |
| CI | `shellcheck` solo miraba `scripts/` | Ahora mira todos los `.sh` del repo |

Lo que salió al comprobarlo: [`scripts-mf0488.txt`](mf0489/evidencias/fase5/scripts-mf0488.txt).
