# OpsMatrix Lab — Enterprise Cyber Security & GRC Operational Framework

## 1. Executive Summary & Identification
* **Project:** OpsMatrix Lab
* **Author:** Xavier Margalef Riestra
* **Modality:** Individual
* **Core Domains:** Defensive Operations, Perimeter Hardening, Network Micro-segmentation, Threat Intelligence, and GRC.

## 2. Threat Modeling & Architectural Scope
OpsMatrix Lab simulates a hardened, production-grade perimeter infrastructure exposed to hostile external networks. The architecture implements Defense-in-Depth and Zero-Trust Network Access (ZTNA) principles to mitigate direct exploitation vectors, lateral movement, and unauthorized data exfiltration. 

Compliance framework mapping:
* **ISO/IEC 27001:** Information Security Management Systems.
* **Esquema Nacional de Seguridad (ENS - RD 311/2022):** Hardening baselines and strict partitioning.
* **NIST SP 800-53 / CIS Benchmarks:** Least-privilege execution and minimal surface exposure.

## 3. Architecture Topology

     [ EXTERNAL THREAT ACTOR / CLIENT ]
                     │
                     ▼ (TLS 1.3)
     [ UBUNTU SERVER (Edge / Host) ]
                     │
       ┌─────────────┴─────────────┐
       │                           │
  [ OpenSSH ]               [ Suricata IDS ]
       │                           │
       └─────────────┬─────────────┘
                     ▼
           [ Docker Engine ]
                     │
       ┌─────────────┴─────────────┐
       │                           │
 [ frontend_net ]            [ backend_net ]
 (Bridge / DMZ)             (Internal / Isolated)
       │                           │
 [ Nginx Alpine ]            [ MariaDB Engine ]
       │                           │
       └────────── web ────────────┘
           (Dual-Homed Container)

## 4. Technical Component & Security Matrix

| Subsystem / Layer | Technology | Security Specification | Operational Function |
| :--- | :--- | :--- | :--- |
| **Host Node** | Ubuntu Server | Linux Kernel LTS + AppArmor | Native execution plane and security sandbox. |
| **Control Plane** | OpenSSH | Hardened daemon, Ed25519 keys | Zero-trust remote administrative access. |
| **Orchestration** | Docker Compose | Manifiesto v3.8, non-root execution | Declarative infrastructure lifecycle. |
| **Perimeter / DMZ** | Nginx Alpine | TLS 1.3 enforcement, secure headers | Reverse proxy terminating external traffic. |
| **Application** | Custom Web | Dual-homed network binding | Controlled transaction processing bridging DMZ. |
| **Persistence** | MariaDB | Restricted bind mounts, isolated socket | Transactional engine in non-routable network. |
| **Threat Detection** | Suricata | Deep Packet Inspection (DPI) | Real-time network anomaly detection. |

## 5. Security Engineering & GRC Controls
* **Network Micro-Segmentation:** Strict division via Docker `internal: true` driver on `backend_net`.
* **Attack Surface Reduction:** Principle of least privilege enforced across all system components.
* **Docs as Code:** Complete operational history maintained via version-controlled Markdown (`ARCHITECTURE.md`, `docs/WORKLOG.md`).
* **Hybrid Validation:** Iterative local testing on macOS containers validated against production Linux nodes.

## 6. Repository Topology

opsmatrix/
├── README.md
├── .env.example
├── docker-compose.yml
├── ARCHITECTURE.md
├── docs/
│   └── WORKLOG.md
├── docker/
├── config/
├── scripts/
└── suricata/
