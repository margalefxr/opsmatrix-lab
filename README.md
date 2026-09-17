# OpsMatrix Lab — Framework Operativo de Ciberseguridad y GRC

![Esquema de Arquitectura - OpsMatrix Lab](https://raw.githubusercontent.com/margalefxr/opsmatrix-lab/main/docs/assets/architecture-schema.png)

## 1. Identificación y Resumen Ejecutivo
* **Proyecto:** OpsMatrix Lab
* **Autor:** Xavier Margalef Riestra
* **Modalidad:** Individual
* **Dominios Clave:** Operaciones Defensivas (Blue Team), Endurecimiento Perimetral (Hardening), Micro-segmentación de Redes, Inteligencia de Amenazas (IDS) y Gobernanza, Riesgos y Cumplimiento (GRC).

## Propuesta de Valor y Enfoque de Mercado (El "Por Qué" y "Para Qué")
* **Segmento Objetivo (Mercado Local B2B):** Diseñado específicamente para despachos profesionales, asesorías fiscales y gestorías locales que manejan información altamente sensible de terceros (datos tributarios, laborales y societarios) y necesitan cumplir rigurosamente con normativas de privacidad sin asumir costes de nubes públicas hiper-escaladas.
* **Problema de Negocio que Resuelve:** Las PYMES del sector profesional sufren ataques dirigidos de *phishing*, robo de credenciales y brechas de datos que derivan en sanciones legales graves y pérdida de confianza del cliente. Este proyecto resuelve la necesidad de disponer de una infraestructura soberana, auditada y con cumplimiento normativo integrado (*by-design*).
* **Función de la Aplicación Web:** Actúa como el portal de cliente transaccional donde los usuarios legítimos interactúan con sus expedientes, operando bajo un estricto control de accesos que permite auditar cualquier anomalía comercial o intento de intrusión.

## Arquitectura de Producto y Especificación Técnica (El "Cómo")
* **Paradigma de Diseño:** Infraestructura simulada bajo los principios de *Defense-in-Depth* y *Zero-Trust*, emulando un entorno de producción expuesto a redes públicas hostiles.
* **Componentes Clave del Stack:**
  * **Capa Perimetral (*Edge-Gateway*):** Terminación de cifrado estricto (TLS 1.3) y filtrado mediante Nginx Alpine.
  * **Aislamiento de Persistencia (*Backend Air-Gapped*):** Red interna con el flag `internal: true` para garantizar que la base de datos MariaDB carezca de pasarelas hacia el exterior, neutralizando vectores de exfiltración o *SSRF*.
  * **Monitorización Defensiva (*Blue Team*):** Sensor IDS Suricata en modo escucha pasiva sobre la interfaz del host para telemetría de red y detección de anomalías en tiempo real.
* **Marco de Cumplimiento (*GRC*):** Alineado con **ISO/IEC 27001**, **Esquema Nacional de Seguridad (ENS - RD 311/2022)** y guías **NIST SP 800-53**.

## Mapeo normativo de cumplimiento:
* **ISO/IEC 27001:** Gestión de seguridad de la información (control de accesos, criptografía y seguridad operacional).
* **Esquema Nacional de Seguridad (ENS - RD 311/2022):** Líneas base de endurecimiento, monitorización continua y particionamiento estricto de dominios.
* **NIST SP 800-53 / CIS Benchmarks:** Ejecución bajo privilegios mínimos y reducción de la superficie de ataque.

## Topología de Arquitectura y Esquema Visual

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
### Distribución Operativa de Componentes:
1. **Capa 1 (`layer1-telemetry`):** Sensor IDS Suricata en modo escucha pasiva sobre la interfaz física del host mediante Inspección Profunda de Paquetes (DPI), garantizando telemetría en tiempo real sin interferir en el tráfico transaccional.
2. **Capa 2 (`layer2-perimeter`):** Perímetro de seguridad, PKI local con Autoridad Certificadora propia (RSA 4096) y terminación estricta de **TLS 1.3** a través de Nginx Alpine.
3. **Capa 3 (`layer3-services`):** Microservicios orquestados mediante Docker Compose. Incluye una red pública (`frontend_net`) en DMZ y una red privada aislada (`backend_net` con el flag `internal: true`) para el motor de base de datos MariaDB, garantizando protección absoluta frente a ataques de exfiltración o SSRF.

## Matriz de Puertos y Servicios
| Subsistema / Capa | Puerto Expuesto | Función Operativa |
| :--- | :--- | :--- |
| **OpenSSH (Host)** | Sí (`22/TCP`) | Administración remota segura con claves Ed25519. |
| **Nginx / Aplicación Web** | Sí (`80/TCP`, `443/TCP`) | Proxy inverso, terminación TLS 1.3 y servicio transaccional público. |
| **MariaDB (Backend)** | No (`3306/TCP` interno) | Motor transaccional aislado en red interna (`internal: true`), sin acceso exterior. |

## Justificaciones Técnicas de Diseño
* **Filosofía *Lean* y Cero Sobreingeniería (*No Overengineering*):** Se descartan arquitecturas distribuidas sobredimensionadas en favor de una orquestación determinista con Docker Compose, maximizando auditabilidad y reduciendo la superficie de fallo.
* **Driver de Red Interno:** El uso de `internal: true` en `backend_net` elimina pasarelas externas, neutralizando ataques de SSRF y exfiltración de datos.
* **Persistencia por Bind Mounts:** Volúmenes locales en el host para garantizar durabilidad transaccional sin la complejidad artificial de clústeres replicados.
* **Paradigma de Validación Híbrida y Sandbox (OrbStack):** Entorno local en macOS optimizado como *sandbox* de alta eficiencia para validar configuraciones antes de desplegar en nodos Linux de producción.
* **Automatización Documental (*Docs as Code*):** Trazabilidad absoluta mediante registros ADR y scripts de validación integrados en el `WORKLOG.md`.

## Matriz de Componentes Técnicos y de Seguridad

| Subsistema / Capa | Tecnología | Especificación de Seguridad | Función Operativa |
| :--- | :--- | :--- | :--- |
| **Nodo Host** | Ubuntu Server / OrbStack Sandbox | Linux Kernel LTS / Motor de contenedores optimizado | Plano de ejecución nativo y aislamiento estricto. |
| **Plano de Control** | OpenSSH | Daemon endurecido, llaves Ed25519 | Acceso administrativo remoto seguro. |
| **Orquestación** | Docker Compose | Manifiesto v3.8, ejecución sin root | Ciclo de vida declarativo y determinista. |
| **Perímetro / DMZ** | Nginx Alpine | Cifrado TLS 1.3, cabeceras HTTP | Proxy inverso de filtrado perimetral. |
| **Capa de Aplicación** | Servicio Web Custom | Enlace a doble red (Dual-Homed) | Procesamiento transaccional controlado. |
| **Persistencia** | MariaDB | Volúmenes *bind mounts* / respaldo local | Motor transaccional aislado con persistencia durable garantizada en host. |
| **Detección de Amenazas** | Suricata | Inspección Profunda de Paquetes (DPI) | Telemetría de red y detección de anomalías. |

## Automatización Operativa y Trazabilidad
* **Scripting de Validación (`scripts/sync_ops.sh`):** Automatiza la comprobación del estado de los contenedores, registra marcas de tiempo e inyecta de forma declarativa las evidencias técnicas en el `WORKLOG.md` antes de la sincronización.
* **Trazabilidad GRC:** Justificación normativa continua adaptada a marcos de referencia de ciberseguridad defensiva.

## Estructura del Repositorio

```text
opsmatrix-lab/
├── ARCHITECTURE.md
├── README.md
├── docs/
│   ├── adr/
│   │   ├── 0001-database-network-isolation.md
│   │   ├── 0002-nids-suricata-host-deployment.md
│   │   ├── 0003-adr-decisions-log.md
│   │   ├── 0004-nids-suricata-rule-engine.md
│   │   ├── 0005-automated-auditability-and-friction-logging.md
│   │   └── 0006-layer2-tls-volume-mounting-troubleshooting.md
│   ├── architecture-schema.md
│   └── WORKLOG.md
├── layer1-telemetry/
│   ├── baseline/check_baseline.sh
│   ├── scripts/
│   └── suricata/rules/local.rules
├── layer2-perimeter/
│   ├── nginx/
│   └── pki/
├── layer3-services/
│   └── docker/docker-compose.yml
└── scripts/
    ├── deploy.sh
    └── sync_ops.sh
```
