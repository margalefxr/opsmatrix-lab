# OpsMatrix-Lab — Security, Telemetry & Infrastructure Architecture

## 1. Identificación del Proyecto (ExP 88 - Fase 1)
* **Nombre del Proyecto:** OpsMatrix-Lab
* **Integrante:** Xavier Margalef Riestra
* **Modalidad:** Individual
* **Especialidad:** Technical & Product Operations / L3 Support & DevSecOps
* **Temática:** Hardening de infraestructura Linux, telemetría NIDS (Suricata), PKI defensiva y orquestación de microservicios.

## 2. Descripción Operativa del Sistema
OpsMatrix-Lab representa la arquitectura base de operaciones de un entorno SaaS transaccional sobre Ubuntu Server 24.04 LTS. La plataforma presta un servicio web de gestión de datos de clientes, procesando autenticación de usuarios, consultas a catálogo y registros de auditoría interna. 

La aplicación web actúa como punto de entrada expuesto, conectando de forma aislada mediante una red interna de Docker con una base de datos MariaDB para la persistencia transaccional y la posterior ejecución de rutinas de backup cifrado. Todo el nodo está monitorizado en tiempo real por un sensor IDS Suricata configurado directamente sobre la interfaz de red del host para capturar y correlacionar la telemetría del sistema.

## 3. Principios de Arquitectura y Gobierno (GRC)
* **Defense in Depth:** Segmentación por capas (Perímetro HTTP/TLS, Telemetría NIDS y Microservicios aislados).
* **Least Privilege:** Exposición mínima de puertos en el host (solo 22/SSH y 443/HTTPS expuestos). Aislamiento total de MariaDB en red privada Docker.
* **Trazabilidad y No Repudio:** Sincronización de marcas de tiempo (*timestamps*) en 4 fuentes clave: SSH (`auth.log`), Reverse Proxy (`access.log`), Contenedores (`docker logs`) e IDS (`eve.json`).
* **Documentación Continua (As-Code):** Registro explícito de cada modificación de infraestructura en el historial de control de versiones.

## 4. Arquitectura del Sistema

```text
                     CLIENTE / AUDITOR / ATACANTE
                                   │
                                   ▼
                          Ubuntu Server Host
                                   │
       ┌───────────────────────────┼───────────────────────────┐
       │                           │                           │
    OpenSSH                    Suricata                     Docker
 (Admin TCP :22)             (NIDS Host)                       │
                                              ┌────────────────┴────────────────┐
                                              │                                 │
                                           WEB App                           MariaDB
                                       (Nginx Proxy)                      (DB TCP :3306)
                                       (TCP 80 / 443)                   [Internal Network]
                                                                                │
                                                                                ▼
                                                                          [Backup Volume]
