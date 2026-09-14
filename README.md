# OpsMatrix - Enterprise SecOps & Infrastructure Hardening Lab

## Overview
Infraestructura de referencia orientada a la validación de arquitectura defensiva en entornos críticos (fintech / procesamiento transaccional). Diseñado para auditar la resiliencia operativa bajo el marco de cumplimiento **ISO/IEC 27001**, aplicando principios de aislamiento de red (*Zero Trust*), telemetría perimetral activa y cifrado estricto antes de fase de producción.

## Topología y Aislamiento (3 Capas)
* **`layer1-telemetry`**: Observabilidad de red en tiempo real mediante **Suricata IDS** acoplado a la interfaz física (`enp2s0`), junto con scripts de auditoría de estado del host.
* **`layer2-perimeter`**: Gestión perimetral, emisión de PKI interna y terminación de cifrado **TLS 1.3** estricto en Nginx Reverse Proxy.
* **`layer3-services`**: Orquestación de contenedores (Nginx + MariaDB) con segmentación estricta de redes (*frontend* / *backend* aislado mediante `internal: true`).

## Gobierno y Seguridad (Docs as Code)
* **Control de Secretos (ISO 27001):** Gobierno de credenciales y exclusión estricta de artefactos sensibles mediante `.gitignore` y variables de entorno mockeadas.
* **Trazabilidad Arquitectónica:** Decisiones documentadas mediante ADRs (*Architecture Decision Records*).
* **Historial Forense:** Convenciones estrictas de commits (`feat:`, `sec:`, `docs:`) para auditorías SOC.
