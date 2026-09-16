# OpsMatrix Lab

## 1. Identificación
* **Proyecto:** OpsMatrix Lab
* **Autor:** Xavier Margalef Riestra
* **Modalidad:** Individual
* **Temática:** Infraestructura de Sistemas, Operaciones L3 y Seguridad (SOC/GRC).

## 2. Descripción del Sistema
OpsMatrix Lab simula una infraestructura de producción endurecida para una plataforma corporativa expuesta a internet. El sistema gestiona un entorno multi-capa segmentado que procesa transacciones de usuarios y registros de bases de datos relacionales bajo políticas de mínimo privilegio. Incorpora monitorización de seguridad perimetral, control estricto de tráfico mediante redes virtuales aisladas y automatización de despliegues declarativos, desacoplando la persistencia de datos del ciclo de vida de los contenedores para garantizar alta disponibilidad y trazabilidad en cumplimiento con normativas de seguridad (GRC).

## 3. Arquitectura del Sistema

     CLIENTE (External)
            │
            ▼
   Ubuntu Server (Edge)
            │
   ┌────────┴────────┐
   │                 │
  SSH             Docker
                     │
      ┌──────────────┴──────────────┐
      │                             │
frontend_net (DMZ)         backend_net (Isolated)
      │                             │
  [ Proxy ]                    [ Database ]
      │                             │
      └─────────── web ─────────────┘
           (Dual-Homed Container)

## 4. Matriz de Componentes Técnicos

| Componente | Tecnología | Función Operativa |
| :--- | :--- | :--- |
| **Servidor Host** | Ubuntu Server / Linux Kernel | Entorno base de ejecución nativo y pruebas de validación multi-plataforma (OrbStack/Ubuntu). |
| **Acceso Remoto** | OpenSSH | Gestión segura de infraestructura y administración remota cifrada. |
| **Orquestación** | Docker / Docker Compose | Despliegue declarativo multi-capa y gestión de contenedores aislados. |
| **Aplicación / Web** | Nginx / Custom Web | Servicio principal frontend, proxy inverso y terminación de tráfico HTTP/HTTPS. |
| **Base de Datos** | MariaDB | Persistencia transaccional aislada en red backend sin exposición pública. |
| **Monitorización / IDS** | Suricata | Inspección profunda de paquetes (DPI), detección de intrusiones y telemetría de red. |

## 5. Valor Diferencial y Operativa (*Engineering Scope*)
* **Docs as Code:** Trazabilidad documental integrada en el repositorio (`ARCHITECTURE.md`, `WORKLOG.md`), eliminando la dependencia de documentación estática desactualizada.
* **Network Zoning:** Segmentación estricta entre la red pública de entrada (`frontend_net`) y el backend de datos (`backend_net` con flag `internal: true`).
* **Validación Híbrida:** Ciclo de desarrollo iterativo local optimizado en macOS para validación de código, con despliegue y pruebas de estrés nativas sobre infraestructura Ubuntu Server.
* **Gobernanza y Riesgos (GRC):** Alineamiento con principios de menor privilegio y endurecimiento de superficies de ataque desde la fase inicial de diseño.

## 6. Estructura del Repositorio

opsmatrix/
├── README.md
├── .gitignore
├── docker-compose.yml
├── ARCHITECTURE.md
├── docs/
│   └── WORKLOG.md
├── docker/
├── config/
├── scripts/
└── suricata/
