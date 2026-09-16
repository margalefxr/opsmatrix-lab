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

## 3. Topología de Arquitectura y Esquema Visual

```text
                 [ CLIENTE / ACTOR EXTERNO ]
                              │
                              ▼ (TLS 1.3 / Perímetro Cifrado)
               [ NODO HOST: UBUNTU SERVER (Edge) ]
                              │
         ┌────────────────────┴────────────────────┐
         │                                         │
    [ OpenSSH ]                             [ Suricata IDS ]
  (Plano de Control - Ed25519)            (Telemetría DPI / OISF)
         │                                         │
         └────────────────────┬────────────────────┘
                              ▼
                     [ Docker Engine ]
                              │
         ┌────────────────────┴────────────────────┐
         │                                         │
   [ frontend_net ]                          [ backend_net ]
   (Bridge / DMZ Exposta)                    (Aislada / internal: true)
         │                                         │
   [ Nginx Alpine ]                          [ MariaDB Engine ]
   (Proxy Inverso / WAF)                     (Bind Mounts / Respaldo Local)
         │                                         ▲
         └─────────────── web ─────────────────────┘
                   (Contenedor Dual-Homed)
```

## 4. Justificaciones Técnicas de Diseño (El Porqué)
* **Filosofía *Lean* y Cero Sobreingeniería (*No Overengineering*):** Se descartan arquitecturas distribuidas sobredimensionadas (ej. Kubernetes o clústeres de alta disponibilidad innecesarios) en favor de una orquestación determinista con Docker Compose. Esto maximiza la auditabilidad, reduce la superficie de fallo y concentra el esfuerzo en el endurecimiento real y la micro-segmentación.
* **Driver de Red Interno:** El uso de `internal: true` en `backend_net` elimina por diseño cualquier interfaz de enrutamiento hacia pasarelas externas, neutralizando ataques de falsificación de peticiones (SSRF) y exfiltración directa.
* **Persistencia por Bind Mounts:** Se opta por volúmenes locales en el host para garantizar durabilidad transaccional sin la complejidad artificial de replicaciones distribuidas en entornos de alcance acotado.
* **Paradigma de Validación Híbrida y Sandbox (OrbStack):** El desarrollo y las pruebas iterativas se ejecutan localmente sobre macOS utilizando **OrbStack** como un motor de contenedores de alto rendimiento y bajo consumo. Este entorno actúa como un *sandbox* seguro para validar despliegues, redes aisladas y cambios de configuración antes de su paso a los nodos de servidor Linux en producción.
* **Automatización Documental (*Docs as Code*):** Toda modificación de infraestructura queda vinculada a scripts de validación que actualizan de forma automatizada las evidencias en el `WORKLOG.md`.

## 5. Matriz de Componentes Técnicos y de Seguridad

| Subsistema / Capa | Tecnología | Especificación de Seguridad | Función Operativa |
| :--- | :--- | :--- | :--- |
| **Nodo Host** | Ubuntu Server / OrbStack Sandbox | Linux Kernel LTS / Motor de contenedores optimizado | Plano de ejecución nativo y aislamiento estricto. |
| **Plano de Control** | OpenSSH | Daemon endurecido, llaves Ed25519 | Acceso administrativo remoto seguro. |
| **Orquestación** | Docker Compose | Manifiesto v3.8, ejecución sin root | Ciclo de vida declarativo y determinista. |
| **Perímetro / DMZ** | Nginx Alpine | Cifrado TLS 1.3, cabeceras HTTP | Proxy inverso de filtrado perimetral. |
| **Capa de Aplicación** | Servicio Web Custom | Enlace a doble red (Dual-Homed) | Procesamiento transaccional controlado. |
| **Persistencia** | MariaDB | Volúmenes *bind mounts* / respaldo local | Motor transaccional aislado con persistencia durable garantizada en host. |
| **Detección de Amenazas** | Suricata | Inspección Profunda de Paquetes (DPI) | Telemetría de red y detección de anomalías. |

## 6. Automatización Operativa y Trazabilidad
* **Scripting de Validación (`scripts/sync_ops.sh`):** Automatiza la comprobación del estado de los contenedores, registra marcas de tiempo e inyecta de forma declarativa las evidencias técnicas en el `WORKLOG.md` antes de la sincronización con el repositorio remoto.
* **Trazabilidad GRC:** Cada cambio se justifica bajo criterios normativos de endurecimiento, cumpliendo con los estándares de auditoría exigidos.

## 7. Estructura del Repositorio

```text
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
│   └── sync_ops.sh
└── suricata/
```
