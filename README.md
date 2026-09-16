# OpsMatrix Lab — Framework Operativo de Ciberseguridad y GRC

## 1. Identificación y Resumen Ejecutivo
* **Proyecto:** OpsMatrix Lab
* **Autor:** Xavier Margalef Riestra
* **Modalidad:** Individual
* **Dominios Clave:** Operaciones Defensivas (Blue Team), Endurecimiento Perimetral (Hardening), Micro-segmentación de Redes, Inteligencia de Amenazas (IDS) y Gobernanza, Riesgos y Cumplimiento (GRC).

## 2. Modelado de Amenazas y Alcance Arquitectónico
OpsMatrix Lab simula una infraestructura de producción expuesta a redes públicas hostiles bajo principios de **Defensa en Profundidad** y **Zero-Trust**. La arquitectura mitiga vectores directos de explotación, movimiento lateral y exfiltración de datos.

Mapeo normativo de cumplimiento:
* **ISO/IEC 27001:** Gestión de seguridad de la información (control de accesos, criptografía y seguridad operacional).
* **Esquema Nacional de Seguridad (ENS - RD 311/2022):** Líneas base de endurecimiento, monitorización continua y particionamiento estricto de dominios.
* **NIST SP 800-53 / CIS Benchmarks:** Ejecución bajo privilegios mínimos y reducción de la superficie de ataque.

## 3. Topología de Arquitectura

[ Actor de Amenaza / Cliente Externo ]
  │
  ▼ (TLS 1.3 / Perímetro Cifrado)
[ Nodo Host: Ubuntu Server (Edge) ]
  ├── Plano de Control: OpenSSH (Cifrado Ed25519)
  ├── Plano de Telemetría: Suricata IDS (DPI / Reglas OISF)
  │
  └── Motor de Contenedores: Docker Engine
        ├── Red Pública: frontend_net (Bridge / DMZ)
        │     └── Proxy Inverso: Nginx Alpine (Terminación TLS / WAF)
        │           │
        │           └── Enlace Dual-Homed (Contenedor Web)
        │                 │
        └── Red Privada: backend_net (Aislada / internal: true)
              └── Base de Datos: MariaDB Engine (Volumetría Restringida)

## 4. Matriz de Componentes Técnicos y de Seguridad

| Subsistema / Capa | Tecnología | Especificación de Seguridad | Función Operativa |
| :--- | :--- | :--- | :--- |
| **Nodo Host** | Ubuntu Server | Linux Kernel LTS + AppArmor | Plano de ejecución nativo y aislamiento de kernel. |
| **Plano de Control** | OpenSSH | Daemon endurecido, llaves Ed25519 | Acceso administrativo remoto seguro. |
| **Orquestación** | Docker Compose | Manifiesto v3.8, ejecución sin root | Ciclo de vida declarativo y determinista. |
| **Perímetro / DMZ** | Nginx Alpine | Cifrado TLS 1.3, cabeceras HTTP | Proxy inverso de filtrado perimetral. |
| **Capa de Aplicación** | Servicio Web Custom | Enlace a doble red (Dual-Homed) | Procesamiento transaccional controlado. |
| **Persistencia** | MariaDB | Volúmenes bind limitados, sin socket | Motor transaccional en red privada. |
| **Detección de Amenazas** | Suricata | Inspección Profunda de Paquetes (DPI) | Telemetría de red y detección de anomalías. |

## 5. Ingeniería de Seguridad y Controles GRC
* **Micro-segmentación de Red:** División estricta mediante el flag `internal: true` de Docker en `backend_net`, bloqueando vectores de pivotaje y ataques de falsificación de peticiones (SSRF).
* **Reducción de Superficie de Ataque:** Principio de mínimo privilegio aplicado en todos los componentes y servicios del sistema.
* **Trazabilidad por Docs as Code:** Historial operacional y decisiones de arquitectura versionadas en el repositorio (`ARCHITECTURE.md`, `docs/WORKLOG.md`).
* **Paradigma de Validación Híbrida:** Prototipado local en macOS validado y desplegado sobre nodos Linux en producción.

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
