# Registro de Decisiones de Arquitectura (ADR) - OpsMatrix

## ADR-000: Elección de Entorno Virtualizado y Host OS
* **Fecha:** 2026-09-14
* **Estado:** Aceptado
* **Contexto:** Se requiere desplegar una infraestructura modular de 3 capas aislada para simulaciones de ciberseguridad y análisis telemétrico.
* **Decisión:** Desplegar Ubuntu Server sobre hipervisor VMware Fusion en subred NAT privada (`172.16.181.132/24`), monitorizando la interfaz física `enp2s0`.
* **Consecuencias:** Máximo rendimiento local y aislamiento directo del tráfico perimetral.

## ADR-001: Adopción del Paradigma "Docs as Code" y Nomenclatura Industrial
* **Fecha:** 2026-09-14
* **Estado:** Aceptado
* **Contexto:** Se deben eliminar nomenclaturas académicas o informales para alinear el proyecto a los estándares de un entorno SOC/SecOps de producción.
* **Decisión:** 
  1. Estructurar el repositorio en capas operativas (`layer1-telemetry`, `layer2-perimeter`, `layer3-services`).
  2. Implementar el estándar de registro ADR y Conventional Commits.
  3. Desplegar una política `.gitignore` estricta para el cumplimiento del control ISO 27001 A.8.9.
* **Consecuencias:** Documentación auditable y trazabilidad industrial en tiempo real.
