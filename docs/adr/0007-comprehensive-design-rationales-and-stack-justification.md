# ADR-0007: Selección de stack y justificación arquitectónica (Fase 1)

> **Del MF0488.** Lo dejo como lo entregué. Lo que ya no es verdad lo tengo apuntado en [correcciones-mf0488.md](../correcciones-mf0488.md).

* **Estado:** Aprobado
* **Autor:** Xavier Margalef Riestra
* **Fecha:** 2026-09-16
* **Contexto:** Modelado defensivo inicial de OpsMatrix Lab bajo criterios de ciberseguridad, operaciones L3 y GRC (ISO/IEC 27001, ENS RD 311/2022).

## Problema

Construir una infraestructura simulada y expuesta a entornos hostiles exige justificar cada decisión técnica para evitar sobreingeniería y mantener un nivel de trazabilidad auditable.

## Decisiones

| Decisión | Por qué | Alternativa descartada |
|---|---|---|
| **Ubuntu Server LTS** como host | Estabilidad de kernel, soporte extendido, integración nativa con AppArmor | — |
| **Docker Compose**, no Kubernetes | Ciclo de vida declarativo y auditable, proporcionado al alcance del laboratorio | Kubernetes: complejidad y superficie de control innecesarias para este proyecto |
| **OrbStack** como sandbox local (macOS) | Ligero, consumo mínimo, compatible de forma nativa con el motor de contenedores para prototipar antes de desplegar en Linux | — |
| **`internal: true`** en `backend_net` | Las redes bridge de Docker enrutan al exterior por defecto; esta flag elimina esa ruta por diseño, no por regla de firewall añadida — bloquea exfiltración y SSRF aunque la capa de aplicación o el proxy sean comprometidos | Exponer el puerto de MariaDB al host o a la red pública |
| **Bind mounts** locales, no clúster replicado | Durabilidad transaccional suficiente para el alcance del proyecto, sin la complejidad operativa de un storage distribuido | Clúster de base de datos replicado |
| **ADRs + WORKLOG automatizado** (*Docs as Code*) | Las decisiones de ingeniería quedan vinculadas a su justificación de seguridad y a evidencia reproducible, requisito de trazabilidad bajo ISO 27001 y ENS | Decisiones no documentadas |
