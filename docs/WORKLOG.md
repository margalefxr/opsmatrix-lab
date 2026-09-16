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
