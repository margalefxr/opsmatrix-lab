# OpsMatrix - Enterprise Operations & SecOps Lab

## Resumen Ejecutivo
Infraestructura modular de 3 capas orquestada sobre Ubuntu Server (`172.16.181.132`). Diseñada bajo principios de **Zero Trust perimetral, visibilidad telemétrica en tiempo real (Suricata IDS) y hardening industrial**.

## Módulos de Infraestructura
* **`layer1-telemetry`:** Captura de eventos en host, firmas Suricata IDS en interfaz `enp2s0` y baseline de salud.
* **`layer2-perimeter`:** PKI empresarial local, terminación TLS 1.3 con Nginx Reverse Proxy y cifrado de payloads.
* **`layer3-services`:** Microservicios aislados (Flask + MariaDB), gestión DRP/Backups firmados y laboratorio de simulación de amenazas (Purple Teaming).

## Matriz de Gobernanza
* **Estándar GRC:** Alineado con ISO/IEC 27001:2022 (A.5.15, A.8.9, A.8.16, A.8.20, A.8.24) y ENS.
* **Metodología:** Docs as Code + Architecture Decision Records (ADR).
