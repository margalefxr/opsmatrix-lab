# OpsMatrix-Lab — Audit Log de Desarrollo (Evidencias de Autoría & Registro Técnico)

Este documento recopila la bitácora cronológica de trabajo, comandos ejecutados, decisiones de arquitectura y registros del repositorio. Sirve como evidencia de autoría y progreso lícito del proyecto ante auditoría o evaluación.

---

## Sesión 1: 14 de Septiembre de 2026 — Concepción, Alcance & Estructuración Base
* **Operador:** Xavier Margalef Riestra (`xaviermargalef`)
* **Entorno:** macOS / VS Code / Git / Terminal

### Acciones Realizadas
1. **Definición de Arquitectura por Capas:**
   - Establecimiento del alcance de `OpsMatrix-Lab`: Entorno SaaS transaccional sobre Ubuntu Server 24.04 LTS.
   - Definición del modelo de segmentación de tres capas (`layer1-telemetry`, `layer2-perimeter`, `layer3-services`).
2. **Inicialización de Repositorio & Git Hardening:**
   - Creación de la estructura base del directorio local.
   - Configuración de `.gitignore` para prevenir la fuga de credenciales, material criptográfico privado (`*.key`, `*.pem`, `ca/private/`) y archivos temporales del sistema.
   - Creación de archivos `.gitkeep` en directorios vacíos para preservar la jerarquía en Git.
3. **Generación de Artefactos Visuales:**
   - Elaboración del esquema de arquitectura en Excalidraw (`docs/architecture.excalidraw`).
   - Redacción del esquema técnico inicial (`docs/architecture-schema.md`) y la estructura HTML (`docs/estructura_proyecto_final.html`).

---

## Sesión 2: 15 de Septiembre de 2026 — Estandarización GRC, Limpieza & Automatización
* **Operador:** Xavier Margalef Riestra (`xaviermargalef`)
* **Entorno:** macOS / Terminal Bash / VS Code / GitHub

### Acciones Realizadas
1. **Reorganización y Limpieza de Repositorios:**
   - Purga de directorios duplicados y estandarización del repositorio bajo el estándar industrial `opsmatrix-lab`.
   - Eliminación de referencias a códigos de entregables académicos en la portada técnica para mantener un perfil profesional de ingeniería (Enterprise SecOps).
2. **Definición de la Ficha Técnica `README.md`:**
   - Redacción y maquetación de los principios de gobierno (Zero Trust, Defense in Depth, No Repudio).
   - Definición de la topología de red (ASCII + Mermaid), la matriz de componentes/puertos y el mapa forense de logs (`auth.log`, `access.log`, `docker logs`, `eve.json`).
3. **Resolución de Formato de Documentación:**
   - Corrección de problemas de renderizado Markdown, secuencias de escape de caracteres y tablas en la interfaz de GitHub.
4. **Diseño del Motor de Registro Continuo:**
   - Definición de la estrategia de separación: `README.md` como especificación de arquitectura y `docs/WORKLOG.md` como diario de trabajo automatizado.

---

## Sesión Actual: Snapshot de Estado

### Registro Automático: \2026-\09-\15 \11:\15:\34 CEST
* **Usuario Local:** xaviermargalef
* **Host:** MacBook-Pro-de-Xavier.local
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
 M layer1-telemetry/scripts/log_work.sh
```
---

### Registro Automático: \2026-\09-\15 \11:\17:\57 CEST
* **Usuario Local:** xaviermargalef
* **Host:** MacBook-Pro-de-Xavier.local
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
```
---

### Registro Automático: \2026-\09-\15 \11:\36:\53 CEST
* **Usuario Local:** xaviermargalef
* **Host:** MacBook-Pro-de-Xavier.local
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
?? docs/adr/0001-database-network-isolation.md
?? docs/adr/0002-nids-suricata-host-deployment.md
```
---

### Registro Automático: \2026-\09-\15 \11:\37:\26 CEST
* **Usuario Local:** xaviermargalef
* **Host:** MacBook-Pro-de-Xavier.local
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
 M layer3-services/docker/docker-compose.yml
?? layer3-services/docker/.env.example
```
---

---

## Sesión 3: 15 de Septiembre de 2026 — Despliegue de Fase 2 & Resolució́n de Incidentes de Entorno
* **Operador:** Xavier Margalef Riestra (`xaviermargalef`)
* **Entorno:** Ubuntu Server 24.04 LTS (SSH Remote Host) / macOS Local

### Fricción Técnica & Registro de Debugging (Troubleshooting Log)
Durante el despliegue del stack de contenedores en el servidor Ubuntu se identificaron y solucionaron las siguientes anomalías:

1. **Error de Contexto de Ejecución (`zsh: command not found: docker`):**
   * *Síntoma:* Intento de ejecución de comandos `docker compose` en la terminal local del Mac sin daemon de Docker iniciado.
   * *Diagnóstico:* Error de ruteo de entorno. La infraestructura `OpsMatrix-Lab` está diseñada para ejecutar sobre el servidor remoto Ubuntu 24.04 LTS.
   * *Resolución:* Redirección de la sesión de trabajo a la terminal con conexión SSH al nodo Ubuntu donde los paquetes `docker.io` y `docker-compose-plugin` operan nativamente.

2. **Despliegue con Código Legacy / Ficheros Ausentes (`cp: cannot stat '.env.example'`):**
   * *Síntoma:* Error al intentar copiar el archivo de variables de entorno en el servidor objetivo.
   * *Diagnóstico:* El repositorio en el servidor Ubuntu se encontraba desincronizado con la rama `main` remota, manteniendo una versión antigua de hace 22 horas con nombres de contenedor heredados (`opsmatrix_db`/`opsmatrix_web`).
   * *Resolución:* Ejecución de `git fetch origin` y `git pull origin main` para aplicar el Fast-forward (831 inserciones, 15 archivos actualizados) previo al despliegue.

3. **Colisión de Redes Virtuales Docker (`Error response from daemon: network docker_backend_net not found`):**
   * *Síntoma:* Fallo al inspeccionar la subred `docker_backend_net`.
   * *Diagnóstico:* Al existir contenedores y redes previas (`docker_red_backend`, `docker_red_frontend`), el daemon no había instanciado las redes declaradas en la nueva sintaxis.
   * *Resolución:* Ejecución de `docker compose down` para purgar los contenedores antiguos y `docker compose up -d --build` para forzar la creación de `docker_backend_net` (`internal: true`) y `docker_frontend_net`.

### Evidencia de Estado Final (Fase 2 Verificada)
* **`opsmatrix-db`:** `Up 5 seconds (healthy)` — MariaDB 11.4 aislado en `docker_backend_net`.
* **`opsmatrix-web`:** `Up (healthy)` — Nginx Alpine expuesto en TCP 80/443.

### Registro Automático: \2026-\09-\15 \11:\44:\19 CEST
* **Usuario Local:** xaviermargalef
* **Host:** MacBook-Pro-de-Xavier.local
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
?? docs/adr/0004-nids-suricata-rule-engine.md
?? layer1-telemetry/suricata/rules/local.rules
```
---

### Registro Automático: \2026-\09-\15 \11:\42:\10 CEST
* **Usuario Local:** server
* **Host:** ubuntuserver
* **Rama Git:** main
vert{}vert{}
* **Último Commit:** 

#### Estado Actual de Archivos (Git Status):
```text
 M docs/WORKLOG.md
```
---

## [2026-09-16] - Consolidación de Arquitectura Lean y Entorno Sandbox
* **ADR Registrado:** Justificada la exclusión de una 3ª red DMZ por overengineering (foco en simplicidad, Lean y aislamiento `--internal`).
* **Entorno Sandbox Validado:** Confirmada la separación de la VM OrbStack `lab-practice` como runtime efímero para pruebas destructivas.
* **Infraestructura:** Mantenimiento de la topología de 2 subredes (`frontend_net` / `backend_net`) combinada con telemetría perimetral.

### [2026-09-16 11:11:42 CEST] - Automated Execution & Evidence Capture
**Archivos Afectados:**
* `README.md`
* `deploy.sh`
* `sync.sh`
* `scripts/`

**Diff Resumido de Cambios:**
```diff
 README.md       | 14 ++++++++++++++
 deploy.sh       | 46 +---------------------------------------------
 docs/WORKLOG.md | 10 ++++++++++
 sync.sh         | 13 +------------
 4 files changed, 26 insertions(+), 57 deletions(-)
```
---

### [2026-09-16 11:11:42 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `deploy.sh`
* `docs/WORKLOG.md`
* `scripts/deploy.sh`
* `scripts/sync.sh`
* `sync.sh`

**Resumen Estadístico del Cambio:**
```diff
 README.md         | 14 ++++++++++++++
 deploy.sh         | 46 +---------------------------------------------
 docs/WORKLOG.md   | 17 +++++++++++++++++
 scripts/deploy.sh | 45 +++++++++++++++++++++++++++++++++++++++++++++
 scripts/sync.sh   | 53 +++++++++++++++++++++++++++++++++++++++++++++++++++++
 sync.sh           | 13 +------------
 6 files changed, 131 insertions(+), 57 deletions(-)
```
---

### [2026-09-16 13:18:17 CEST] - Automated Execution & Evidence Capture
**Archivos Afectados:**
* `README.md`

**Diff Resumido de Cambios:**
```diff
 README.md       | 10 ++++++++++
 docs/WORKLOG.md |  7 +++++++
 2 files changed, 17 insertions(+)
```
---

### [2026-09-16 13:18:17 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `docs/WORKLOG.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md       | 10 ++++++++++
 docs/WORKLOG.md | 12 ++++++++++++
 2 files changed, 22 insertions(+)
```
---

### [2026-09-16 13:41:39 CEST] - Automated Execution & Evidence Capture
**Archivos Afectados:**
* `README.md`

**Diff Resumido de Cambios:**
```diff
 README.md       | 11 +++++++++++
 docs/WORKLOG.md |  7 +++++++
 2 files changed, 18 insertions(+)
```
---

### [2026-09-16 13:41:39 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `docs/WORKLOG.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md       | 11 +++++++++++
 docs/WORKLOG.md | 12 ++++++++++++
 2 files changed, 23 insertions(+)
```
---

### [2026-09-16 13:59:05 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `layer2-perimeter/nginx/default.conf`
* `layer3-services/docker/docker-compose.yml`

**Resumen Estadístico del Cambio:**
```diff
 layer2-perimeter/nginx/default.conf       | 17 +++++---------
 layer3-services/docker/docker-compose.yml | 39 +++++++++++--------------------
 2 files changed, 19 insertions(+), 37 deletions(-)
```
---

## [2026-09-16] Incidencia & Resolucion: Terminacion TLS 1.3 y Ajuste de Volumenes

### Sintomas Detectados
* Error al consultar puerto 443: curl: (35) Send failure: Broken pipe
* Fallo interno de Nginx: cannot load certificate /etc/nginx/ssl/server.crt

### Acciones de Diagnostico & Correccion
1. Inspeccion de listeners: docker exec -it opsmatrix-web ss -tulpn
2. Generacion de certificados en: layer2-perimeter/nginx/ssl/
3. Correccion de volumenes en: layer3-services/docker/docker-compose.yml
4. Validacion sintactica: docker exec -it opsmatrix-web nginx -t (successful)

### Evidencia de Respuesta HTTP 200 OK
HTTP/1.1 200 OK
Server: nginx/1.31.5
Date: Wed, 16 Sep 2026 11:53:36 GMT
Content-Type: application/json
Content-Length: 48

{"status":"200 OK", "zone":"Layer2 TLS Active"}

### [2026-09-16 14:27:16 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/WORKLOG.md`
* `docs/adr/0005-layer2-tls-volume-mounting-troubleshooting.md`

**Resumen Estadístico del Cambio:**
```diff
 docs/WORKLOG.md                                     | 21 +++++++++++++++++++++
 ...05-layer2-tls-volume-mounting-troubleshooting.md | 19 +++++++++++++++++++
 2 files changed, 40 insertions(+)
```
---

### [2026-09-16 14:29:11 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/adr/0006-layer2-tls-volume-mounting-troubleshooting.md`

**Resumen Estadístico del Cambio:**
```diff
 ...leshooting.md => 0006-layer2-tls-volume-mounting-troubleshooting.md} | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```
---

### [2026-09-16 15:51:02 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `ARCHITECTURE.md`

**Resumen Estadístico del Cambio:**
```diff
 ARCHITECTURE.md | 10 ++++++++++
 1 file changed, 10 insertions(+)
```
---

### [2026-09-16 16:08:13 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `config/.gitkeep`
* `docker/.gitkeep`
* `scripts/.gitkeep`
* `suricata/.gitkeep`

**Resumen Estadístico del Cambio:**
```diff
 README.md         | 226 +++++++++++++++---------------------------------------
 config/.gitkeep   |   0
 docker/.gitkeep   |   0
 scripts/.gitkeep  |   0
 suricata/.gitkeep |   0
 5 files changed, 60 insertions(+), 166 deletions(-)
```
---

### [2026-09-16 16:14:16 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 84 +++++++++++++++++++++++++++++++++------------------------------
 1 file changed, 44 insertions(+), 40 deletions(-)
```
---

### [2026-09-16 16:19:48 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 95 ++++++++++++++++++++++++++++++++++-----------------------------
 1 file changed, 51 insertions(+), 44 deletions(-)
```
---

### [2026-09-16 16:22:10 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 94 ++++++++++++++++++++++++++++++---------------------------------
 1 file changed, 44 insertions(+), 50 deletions(-)
```
---

### [2026-09-16 16:25:43 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 33 +++++++++++++++++----------------
 1 file changed, 17 insertions(+), 16 deletions(-)
```
---

### [2026-09-16 16:28:16 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 7 ++++---
 1 file changed, 4 insertions(+), 3 deletions(-)
```
---

### [2026-09-16 16:29:29 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 25 +++++++++----------------
 1 file changed, 9 insertions(+), 16 deletions(-)
```
---

### [2026-09-16 16:30:25 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 37 ++++++++++++++++++++++++++++++-------
 1 file changed, 30 insertions(+), 7 deletions(-)
```
---

### [2026-09-16 16:35:08 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `scripts/sync_ops.sh`

**Resumen Estadístico del Cambio:**
```diff
 README.md           | 17 ++++++++---------
 scripts/sync_ops.sh | 35 +++++++++++++++++++++++++++++++++++
 2 files changed, 43 insertions(+), 9 deletions(-)
```
---

### [2026-09-16 16:37:58 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 3 ++-
 1 file changed, 2 insertions(+), 1 deletion(-)
```
---

### [2026-09-16 16:39:11 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 17 +++++++++--------
 1 file changed, 9 insertions(+), 8 deletions(-)
```
---

### [2026-09-16 16:43:40 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`

**Resumen Estadístico del Cambio:**
```diff
 README.md | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```
---

### [2026-09-16 16:47:33 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `README.md`
* `deploy.sh`
* `docs/adr/0003-adr-decisions-log.md`
* `docs/estructura_proyecto_final.html`
* `sync.sh`

**Resumen Estadístico del Cambio:**
```diff
 README.md                                          |  46 ++--
 deploy.sh                                          |   1 -
 ...-decisions-log.md => 0003-adr-decisions-log.md} |   0
 docs/estructura_proyecto_final.html                | 282 ---------------------
 sync.sh                                            |   1 -
 5 files changed, 29 insertions(+), 301 deletions(-)
```
---

---

## [Fase 1 — Formalización de Justificaciones Técnicas (ADR-0007)] — 2026-09-16
* **Autor:** Xavier Margalef Riestra
* **Objetivo:** Consolidación de un documento ADR específico para registrar el "por qué" de cada componente, la exclusión de sobreingeniería y las decisiones de arquitectura defensiva.
* **Evidencia Generada:** Creación del fichero `docs/adr/0007-comprehensive-design-rationales-and-stack-justification.md`.

### [2026-09-16 16:50:25 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/WORKLOG.md`
* `docs/adr/0007-comprehensive-design-rationales-and-stack-justification.md`

**Resumen Estadístico del Cambio:**
```diff
 docs/WORKLOG.md                                    |  7 ++++++
 ...ve-design-rationales-and-stack-justification.md | 25 ++++++++++++++++++++++
 2 files changed, 32 insertions(+)
```
---

---

## [Fase 1 y Fase 2 — Cierre y Validación de Infraestructura Docker] — 2026-09-17
* **Autor:** Xavier Margalef Riestra
* **Objetivo:** Verificación y cierre formal de los requisitos de la Fase 2 (Servidor Ubuntu, OpenSSH, Docker Engine, Docker Compose, Web ↔ DB con micro-segmentación y persistencia por bind mounts).

### Evidencias de Validación:
* **Servidor y Control:** Ubuntu operativo con daemon SSH endurecido.
* **Orquestación:** Manifiesto declarativo en layer3-services/docker/docker-compose.yml validado.
* **Aislamiento y Redes:** Conectividad web-base de datos asegurada mediante red privada con aislamiento perimetral (internal: true).
* **Persistencia:** Volúmenes locales configurados para garantizar la durabilidad de los datos en el host.
* **Tabla de Puertos:** Mapeo documentado (SSH expuesto, Web expuesta en 80/443, MariaDB bloqueada a uso exclusivamente interno).

### [2026-09-17 10:29:30 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/architecture-master.excalidraw`

**Resumen Estadístico del Cambio:**
```diff
 docs/architecture-master.excalidraw | 39 +++++++++++++++++++++++++++++++++++++
 1 file changed, 39 insertions(+)
```
---

### [2026-09-17 12:06:19 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/assets/README.md`

**Resumen Estadístico del Cambio:**
```diff
 docs/assets/README.md | 3 +++
 1 file changed, 3 insertions(+)
```
---

### [2026-09-17 16:32:31 CEST] - Preservación Autónoma de Evidencias (GRC Engine)
**Archivos Modificados en Commit:**
* `docs/assets/architecture-schema.png`

**Resumen Estadístico del Cambio:**
```diff
 docs/assets/architecture-schema.png | Bin 0 -> 147122 bytes
 1 file changed, 0 insertions(+), 0 deletions(-)
```
---

## [2026-09-18 07:25:00 UTC] — Estandarización Temporal y Endurecimiento de Sincronización NTP
* **Acción Técnica:** Fijación del huso horario del nodo host a **UTC** mediante `timedatectl` y verificación de sincronización del demonio **Chrony** frente a fuentes upstream de Ubuntu (Stratum 2, IP: `185.125.190.122`).
* **Justificación GRC y Forense:** Garantizar la integridad cronológica y la correlación cruzada de eventos sin sesgos de horario de verano. Evita asimetrías horarias entre las alertas de red del NIDS (Suricata), los registros de acceso del plano de control (OpenSSH) y las transacciones del motor de persistencia (MariaDB).
* **Evidencia de Validación:** `timedatectl status` confirma zona horaria UTC activa y `chrony sources` valida la sincronización estable del reloj del sistema.
