# ADR-0007: Justificaciones Arquitectónicas Integrales y Selección de Stack (Fase 1)

* **Estado:** Aprobado
* **Autor:** Xavier Margalef Riestra
* **Fecha:** 2026-09-16
* **Contexto:** Definición inicial y modelado defensivo del framework OpsMatrix Lab bajo criterios de ciberseguridad, L3 Operations y GRC (ISO/IEC 27001, ENS - RD 311/2022).

## 1. Contexto y Problemática
Construir una infraestructura simulada expuesta a entornos hostiles requiere justificar de manera rigurosa cada decisión tecnológica para evitar la sobreingeniería (*overengineering*) y garantizar un nivel de blindaje y trazabilidad de grado de producción.

## 2. Decisiones y Justificaciones Técnicas (El "Por Qué")

### A. Elección del Stack y Orquestación (Docker Compose + Ubuntu Server)
* **Por qué Ubuntu Server como Host:** Se selecciona una distribución LTS por su estabilidad de kernel, soporte extendido, integración nativa con AppArmor y el amplio estándar de mercado para despliegues perimetrales (Edge).
* **Por qué Docker Compose en lugar de Kubernetes:** Se aplica estrictamente la filosofía *Lean* y el principio de no sobreingeniería. Kubernetes introduciría una complejidad innecesaria (*overengineering*) y una superficie de control sobredimensionada para el alcance acotado del laboratorio. Docker Compose ofrece un ciclo de vida declarativo, determinista y auditable, concentrando los recursos en el endurecimiento de red y la seguridad defensiva.
* **Por qué OrbStack como Sandbox Local:** En la fase de prototipado y validación sobre macOS, se utiliza OrbStack por su extrema ligereza, eficiencia en el consumo de recursos y compatibilidad nativa con el motor de contenedores, simulando con alta fidelidad el comportamiento de producción sin penalizar el rendimiento del host de desarrollo.

### B. Micro-segmentación de Red y Aislamiento del Backend
* **Por qué el driver `internal: true` en `backend_net`:** Las redes Docker estándar (*bridge*) permiten de forma predeterminada el enrutamiento hacia pasarelas externas si no se restringen explícitamente. Al aplicar el flag `internal: true`, se secciona la red privada de persistencia, bloqueando por diseño cualquier intento de exfiltración de datos o ataques de falsificación de peticiones del lado del servidor (SSRF) en caso de que la capa de aplicación o el proxy sufran una brecha de seguridad.

### C. Estrategia de Persistencia (Bind Mounts Locales vs. Clústeres Replicados)
* **Por qué volúmenes *bind mounts* locales:** Se prescinde de arquitecturas distribuidas de almacenamiento o replicación compleja en clústeres. El uso de volúmenes enlazados directamente al sistema de ficheros del host ofrece durabilidad transaccional inmediata, facilita las labores de respaldo (*backup*) manual o automatizado y mantiene la simplicidad operativa acorde al rol de operaciones L3.

### D. Paradigma de Trazabilidad y Docs as Code
* **Por qué automatizar el WORKLOG y centralizar ADRs:** Para cumplir con normativas de gobernanza y cumplimiento (GRC) como ISO/IEC 27001 y el ENS, las decisiones de ingeniería no pueden ser implícitas. El uso de registros ADR y scripts de validación operativos (*Docs as Code*) garantiza que cada cambio técnico esté intrínsecamente vinculado a su justificación de seguridad y a evidencias de ejecución reproducibles.
