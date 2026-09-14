# OpsMatrix - Enterprise Operations & SecOps Hardening Lab

## Resumen Ejecutivo
**OpsMatrix** es una infraestructura de referencia diseñada para simular la plataforma central de procesamiento de datos transaccionales de una entidad fintech o proveedor de servicios críticos en Europa. 

El proyecto demuestra competencias avanzadas en **Technical Operations, SRE y SecOps L3**, implementando una arquitectura resiliente y defendible orientada a superar las exigencias de certificación bajo el marco **ISO/IEC 27001** previo a su paso a producción.

## Arquitectura Modular de 3 Capas (Zero Trust)
* **`layer1-telemetry`**: Observabilidad activa y monitorización perimetral de red en tiempo real mediante **Suricata IDS** sobre la interfaz física (`enp2s0`), junto con scripts de auditoría de salud del sistema.
* **`layer2-perimeter`**: Gestión de perimetro seguro, emisión de PKI local y terminación de cifrado estricto **TLS 1.3** en Nginx Reverse Proxy.
* **`layer3-services`**: Orquestación de microservicios aislados (Nginx + MariaDB) con segmentación estricta de redes (*frontend* / *backend* con aislamiento `internal: true`).

## Marco de Gobernanza ("Docs as Code")
* **Trazabilidad de Decisiones:** Registro estricto mediante ADRs (*Architecture Decision Records*).
* **Control de Secretos (ISO 27001):** Gobierno riguroso de credenciales y exclusión de artefactos sensibles mediante `.gitignore`.
* **Historial Forense:** Convenciones estrictas decommits (`feat:`, `sec:`, `docs:`) para auditorías SOC.
