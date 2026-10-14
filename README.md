# OpsMatrix Lab — Infraestructura defensiva por capas

![Esquema de Arquitectura - OpsMatrix Lab](https://raw.githubusercontent.com/margalefxr/opsmatrix-lab/main/docs/assets/architecture-schema.png)

**Autor:** Xavier Margalef Riestra
**Dominios:** Blue Team · Hardening perimetral · Micro-segmentación de red · IDS · GRC
**Paradigma:** Defense-in-Depth y Zero Trust, en espejo con los vectores de ataque documentados en [MSA-Playbook](https://github.com/margalefxr/MSA-Playbook)

## Qué es

Infraestructura simulada de un portal transaccional (tipo despacho profesional / gestoría) expuesta a redes públicas hostiles, diseñada para demostrar controles defensivos reales y no solo su descripción: terminación TLS en el perímetro, backend de base de datos sin ruta a internet, e IDS en escucha pasiva sobre el host.

## Arquitectura

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
   (Bridge / DMZ expuesta)                   (internal: true)
         │                                         │
   [ Nginx Alpine ]                          [ MariaDB Engine ]
   (Proxy inverso / WAF)                     (Bind mounts / backup local)
         │                                         ▲
         └─────────────── web ─────────────────────┘
                   (Contenedor dual-homed)
```

| Capa | Componente | Función |
|---|---|---|
| **01 · Telemetría** (`layer1-telemetry`) | Suricata IDS | Escucha pasiva sobre la interfaz del host, DPI, detección de anomalías en tiempo real |
| **02 · Perímetro** (`layer2-perimeter`) | Nginx Alpine + PKI propia (RSA 4096) | Terminación TLS 1.3, proxy inverso, CA local |
| **03 · Servicios** (`layer3-services`) | Docker Compose: `frontend_net` (DMZ) + `backend_net` (`internal: true`) | MariaDB sin ruta de salida a internet — neutraliza exfiltración y SSRF |

## Puertos expuestos

| Servicio | Puerto | Expuesto |
|---|---|---|
| OpenSSH (host) | 22/TCP | Sí — claves Ed25519 |
| Nginx | 80/TCP, 443/TCP | Sí — TLS 1.3 |
| MariaDB | 3306/TCP | No — solo accesible desde `backend_net` |

## Por qué está construido así

- **Docker Compose, no Kubernetes.** El alcance del laboratorio no justifica la complejidad operativa de un orquestador de clúster; Compose da un ciclo de vida declarativo y auditable sin sobreingeniería.
- **`internal: true` en `backend_net`.** Las redes bridge de Docker enrutan hacia el exterior por defecto; marcar la red como interna elimina esa ruta por diseño, no por configuración de firewall añadida.
- **Bind mounts, no clúster replicado.** Durabilidad suficiente para el alcance del proyecto sin la complejidad operativa de un storage distribuido.
- **OrbStack como sandbox local (macOS)** para validar antes de desplegar en el nodo Ubuntu de producción.

Justificación detallada de cada decisión, con alternativas descartadas: [`docs/adr/`](./docs/adr/).

## Cumplimiento normativo

Alineado con **ISO/IEC 27001** (control de accesos, criptografía, seguridad operacional), **ENS** (RD 311/2022 — líneas base de hardening y monitorización continua) y **NIST SP 800-53 / CIS Benchmarks** (mínimo privilegio, reducción de superficie de ataque).

## Automatización y trazabilidad

`scripts/sync_ops.sh` valida el estado de los contenedores, registra marcas de tiempo e inyecta la evidencia en [`docs/WORKLOG.md`](./docs/WORKLOG.md) antes de cada sincronización con el repositorio remoto.

## Estructura del repositorio

```text
opsmatrix-lab/
├── ARCHITECTURE.md
├── README.md
├── docs/
│   ├── adr/                  ← decisiones de diseño (ADR), una por fichero
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

## Repositorios relacionados

- **[MSA-Playbook](https://github.com/margalefxr/MSA-Playbook)** — metodología ofensiva; OpsMatrix Lab implementa, en espejo, los controles defensivos que neutralizan esos mismos vectores.
- **[CyberOps-Portfolio](https://github.com/margalefxr/CyberOps-Portfolio)** — auditorías reales y laboratorios donde se aplica esa metodología.
