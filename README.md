# OpsMatrix Lab — Enterprise Architecture & Compliance Framework

## 1. Identificación
* **Proyecto:** OpsMatrix Lab
* **Autor:** Xavier Margalef Riestra
* **Modalidad:** Individual
* **Alcance:** Infraestructura L3, Automatización Declarativa, Seguridad Perimetral y GRC.

## 2. Descripción del Sistema y Alineamiento GRC
Infraestructura de producción simulada bajo principios de defensa en profundidad y segmentación estricta. Diseñada para cumplir con los estándares de seguridad de la información (**ISO/IEC 27001**) y el **Esquema Nacional de Seguridad (ENS)**. El sistema gestiona transacciones desacopladas mediante contenedores orquestados con Docker Compose, aplicando aislamiento de bases de datos en redes privadas virtuales, monitorización de tráfico mediante inspección profunda de paquetes (DPI) y trazabilidad completa de cambios bajo el paradigma *Docs as Code*.

## 3. Arquitectura de Red y Topología de Componentes

     [ EXTERNAL CLIENT ]
             │ (HTTPS / TLS 1.3)
             ▼
     [ UBUNTU SERVER (Edge Node) ]
             │
             ├── Management: OpenSSH (Encrypted Control Plane)
             ├── Telemetry:  Suricata IDS (DPI / Threat Detection)
             │
             └── Docker Engine (Container Runtime)
                   │
                   ├── frontend_net (Bridge / DMZ Exposta)
                   │     └── [ proxy: Nginx Alpine ] (Reverse Proxy & Terminus)
                   │           │
                   │           └── (Dual-Homed Interface)
                   │                 │
                   └── backend_net (Bridge / internal: true - Aisada)
                         │
                         ├── [ web: Custom Web Service ]
                         └── [ db: MariaDB Engine ] (Storage Volumetry)

## 4. Matriz de Componentes Técnicos

| Capa / Subsistema | Tecnología | Especificación Técnica | Función Operativa |
| :--- | :--- | :--- | :--- |
| **Host Node** | Ubuntu Server | Linux Kernel LTS | Entorno base de ejecución y nodo de despliegue principal. |
| **Control Plane** | OpenSSH | Server Daemon / Ed25519 | Acceso remoto cifrado y administración de infraestructura. |
| **Orchestration** | Docker Compose | Manifiesto v3.8 / Declarativo | Gestión de ciclos de vida y aislamiento de servicios. |
| **Perimeter / DMZ** | Nginx Alpine | Proxy Inverso / TLS Termination | Control de tráfico de entrada en `frontend_net`. |
| **Application Layer** | Nginx / Web | Contenedor Dual-Homed | Conectividad simultánea entre DMZ y red interna aislada. |
| **Persistence** | MariaDB | Motor Relacional / Bind Mounts | Almacenamiento transaccional aislado en `backend_net`. |
| **Security / IDS** | Suricata | DPI / Reglas OISF | Monitorización de tramas de red y detección de intrusiones. |

## 5. Gobernanza, Riesgos y Cumplimiento (GRC)
* **Network Zoning:** Aislamiento absoluto de la base de datos mediante el flag de Docker `internal: true` en `backend_net`, impidiendo cualquier enrutamiento hacia el exterior.
* **Least Privilege Access:** Exposición mínima de puertos al host (solo 80/443 en proxy y SSH restringido).
* **Trazabilidad Operativa:** Versionado estricto de manifiestos y bitácoras técnicas de ingeniería (`docs/WORKLOG.md`, `ARCHITECTURE.md`).
* **Validación Multi-Entorno:** Pruebas de integración local en macOS/OrbStack con despliegue final validado sobre entornos nativos Linux.

## 6. Estructura del Repositorio

opsmatrix/
├── README.md
├── .env.example
├── docker-compose.yml
├── ARCHITECTURE.md
├── docs/
│   └── WORKLOG.md
├── docker/
├── config/
│   └── perimeter/
├── scripts/
└── suricata/
