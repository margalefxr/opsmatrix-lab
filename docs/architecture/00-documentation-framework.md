# Marco Metodológico de Documentación Técnico-Operativa (Docs as Code)

## 1. Principios de Documentación SecOps
Para garantizar trazabilidad, auditoría y mantenibilidad en entornos de producción, la documentación se gestiona mediante el paradigma **Docs as Code**:
* **Co-localización:** La documentación reside en el mismo repositorio de código (`docs/`), garantizando que la evolución técnica e infraestructura se mantengan sincronizadas en cada commit.
* **Architecture Decision Records (ADR):** Toda decisión estructural, selección de stack o política de seguridad se registra mediante la plantilla formal Nygard ADR.
* **Sintaxis Estándar:** Uso exclusivo de Markdown (`.md`) para documentación técnica y HTML5 semántico para entregables ejecutivos de dirección.

## 2. Política de Commits Trazables (Conventional Commits)
El historial de Git actúa como evidencia forense en auditorías. Se aplica la especificación *Conventional Commits*:
* `feat(scope):` Implementación de nuevos componentes de infraestructura o servicios.
* `sec(scope):` Aplicación de controles de hardening, reglas de IDS o políticas de red.
* `docs(scope):` Actualización de ADRs, diagramas o dossiers ejecutivos.
* `fix(scope):` Corrección de fallos de configuración o vulnerabilidades detectadas.

## 3. Matriz de Gobernanza de Secretos (ISO/IEC 27001 Control A.8.9)
Para evitar la fuga accidental de credenciales o claves privadas en el control de versiones:
* Los archivos confidenciales (`.env`, `.key`, `.pem`, `.crt`) quedan bloqueados a nivel de kernel de Git mediante `.gitignore`.
* Se proveen únicamente plantillas sanitizadas (`.env.example`) para aprovisionamiento seguro.
