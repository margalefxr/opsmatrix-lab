# Lo del MF0488 que ya no es cierto (o que no se podía demostrar)

Los documentos del MF0488 (`ARCHITECTURE.md`, `docs/adr/`, `docs/WORKLOG.md`, `docs/architecture-schema.md`, `docs/architecture/`, `docs/assets/` y los `.excalidraw`) se quedan como estaban: son lo que se entregó y se corrigió entonces. Esta tabla dice qué partes ya no valen, qué hay hoy y dónde está la prueba. **Cuando no coincidan, manda lo del MF0489.**

## Documentos

| Dónde | Qué dice | Qué hay hoy | Evidencia |
|---|---|---|---|
| README antiguo, `architecture-schema.md`, ADR-0006 | "Solo TLS 1.3" | TLS 1.2 y 1.3. 1.1 rechazado | [Fase 4 §3](mf0489/fase4-auditoria-tls-monitorizacion.md#3-versiones-tls), [`check-mac-github.txt`](mf0489/evidencias/fase5/check-mac-github.txt) §8 |
| ADR-0006 | Certificados autofirmados RSA 2048 | CA propia RSA 4096 (fuera de la VM) y certificado del servidor RSA 3072 firmado por ella | [Fase 2](mf0489/fase2-pki.md) |
| ADR-0001, ADR-0002, `docs/WORKLOG.md` | Ubuntu Server 24.04 LTS | Ubuntu 26.04 LTS | [`fase5-ssh-firewall-backup.txt`](mf0489/evidencias/fase5/fase5-ssh-firewall-backup.txt) (final) |
| ADR-0001 | "La única forma de llegar a la BBDD es a través de Nginx" y "los intentos de acceso quedan en los logs de Nginx" | Nginx **no** está en `backend_net` y ni resuelve `db`. Solo la app habla con MariaDB | [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §9 y §10 |
| ADR-0001, README antiguo | WAF | No hay WAF. Nginx es solo reverse proxy | [`default.conf`](../layer2-perimeter/nginx/default.conf) |
| ADR-0001 | `internal: true` funciona con reglas en la cadena `DOCKER-USER` | No revisé las reglas de iptables. Lo comprobado es el efecto: la BBDD no sale a internet | [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §10 |
| ADR-0002 | Suricata detecta escaneos Nmap. Captura con eBPF | Ninguna regla busca Nmap. Captura con `af-packet`, sin eBPF | [`local.rules`](../layer1-telemetry/suricata/rules/local.rules), [`suricata-config.txt`](mf0489/evidencias/fase4/suricata-config.txt) |
| ADR-0004 | 1000001 = ICMP Echo Request. 1000002 = user-agent de Nmap, Nikto o sqlmap | 1000001 salta con **cualquier** ICMP (también IPv6 tipo 133). 1000002 salta con cualquier TCP al 80, no mira el user-agent. Las de Nmap estaban en el repo, pero no eran las que corrían en la VM | [`fase4-intento1-vm.txt`](mf0489/evidencias/fase4/fase4-intento1-vm.txt), [`feedback-mf0488.txt`](mf0489/evidencias/fase4/feedback-mf0488.txt) |
| ADR-0005 | Un hook `pre-commit` actualiza el WORKLOG. "Trazabilidad 100% garantizada" | Hubo un hook local: los commits `e1d76a0` y `1e19d5f` del 15/09 cambian el WORKLOG y su mensaje dice que probaban el hook, pero git no sube los hooks: quien clone el repo no lo tiene. No garantiza nada. El WORKLOG del MF0489 está hecho a mano | `git show e1d76a0 --stat` |
| ADR-0003 | Numeración ADR-000, 001 y 003 dentro de un archivo | Choca con los archivos `0001`…`0007`. Se deja como está | — |
| ADR-0003 | OpsMatrix es una fintech | Es el portal de una gestoría (README) | — |
| `docs/WORKLOG.md` (sesión 3) | MariaDB 11.4, contenedores `(healthy)`, redes `docker_backend_net` y `docker_frontend_net` | `mariadb:10.11`, sin `healthcheck` en el compose, redes `opsmatrix-lab_frontend_net` y `opsmatrix-lab_backend_net`. Las `docker_*` se borraron en la Fase 5 | [`docker-compose.yml`](../docker-compose.yml), [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §7, §9 y §13 |
| ADR-0007 | Persistencia con bind mounts | Volumen con nombre `mariadb_data` | [Fase 3 §7](mf0489/fase3-https-docker.md#7-app-y-persistencia) |
| ADR-0007 | AppArmor y OrbStack | No configuré ni comprobé AppArmor. Las pruebas en local del MF0489 no se hicieron en OrbStack | — |
| `architecture-schema.md` | Contenedor `opsmatrix_web` en las dos redes | `reverse-proxy` solo en `frontend_net`. `app` en las dos | [`check-vm-github.txt`](mf0489/evidencias/fase5/check-vm-github.txt) §9 |
| `docs/architecture/00-documentation-framework.md` | `.gitignore` bloquea los `.crt` | Los certificados son públicos y están en `layer2-perimeter/pki/`. Se bloquean claves, `.env` y copias | [`.gitignore`](../.gitignore) |
| `docs/architecture/00-documentation-framework.md` | Conventional Commits y entregables en HTML5 | Los commits del MF0489 empiezan por `MF0489:`. No hay entregables en HTML | `git log` |
| `docs/assets/README.md` | Los diagramas se ven en `ARCHITECTURE.md` | `ARCHITECTURE.md` no tiene imágenes. El diagrama actual es [`arquitectura-final.png`](mf0489/arquitectura-final.png) | — |
| `architecture.excalidraw`, `architecture-master.excalidraw`, `assets/architecture-schema.png` | Diagramas del MF0488 | Sustituidos por [`arquitectura-final.mmd`](mf0489/arquitectura-final.mmd) | — |

## Scripts y carpetas

| Qué | Problema | Qué hice |
|---|---|---|
| `scripts/sync_ops.sh` | Hace `git add .` y `git push origin main` sin revisar lo que sube | No se usa en el MF0489. Se sube a mano después de revisar, y la CI lo vuelve a comprobar. Marcado en su cabecera |
| `layer1-telemetry/scripts/log_work.sh` y `capture_debug.sh` | Escriben en `docs/WORKLOG.md` (MF0488) | No se usan en el MF0489. Marcados en su cabecera |
| `layer1-telemetry/baseline/check_baseline.sh` | Con 0 alertas escribía `0` dos veces (`grep -c` ya escribe 0 y luego `\|\| echo "0"` añade otro) | Corregido con `\|\| true`. Es una línea base de salud. La de actividad está en la [Fase 4](mf0489/fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| Carpetas `layer2-perimeter/diffie-hellman/` y `layer3-services/nginx/conf.d/` | Vacías (solo `.gitkeep`). Parecían decir que había parámetros DH o una config de Nginx ahí | Borradas. Nginx no usa `ssl_dhparam`: en TLS 1.2 negocia ECDHE ([`fase4-mac.txt`](mf0489/evidencias/fase4/fase4-mac.txt)) |
| `.gitkeep` en carpetas que ya tienen archivos | Sobraban | Borrados |
| CI | `shellcheck` solo miraba `scripts/` | Ahora mira todos los `.sh` del repo |

Salida de las comprobaciones: [`scripts-mf0488.txt`](mf0489/evidencias/fase5/scripts-mf0488.txt).
