# OpsMatrix - Topologia de Arquitectura e Infraestructura

## Diagrama de Capas (Modelo Zero Trust)

HOST: 172.16.181.132 (Ubuntu Server)
- [ LAYER 1: TELEMETRY ]
  -> Suricata IDS (Monitoreo activo sobre interfaz fisica enp2s0)

- [ LAYER 2: PERIMETER ]
  -> Nginx Reverse Proxy (Terminacion TLS 1.3 estricta + PKI local)

- [ LAYER 3: SERVICES ] (Docker Stack Aislado)
  -> opsmatrix_web (Frontend / Red externa + interna)
  -> opsmatrix_db  (MariaDB / Red interna aislada internal: true)

## Descripcion de Componentes Activos
1. Layer 1: Suricata IDS operando como demonio systemd, analizando telemetria perimetral en tiempo real.
2. Layer 2: Emision interna de certificados mediante Autoridad Certificadora propia con cifrado exclusivo TLS 1.3.
3. Layer 3: Segmentacion estricta de redes de contenedores para blindar la base de datos frente a accesos directos desde el exterior.
