# ADR 0002: Posicionamiento del Sensor NIDS Suricata en la Capa del Host

* **Estatus:** Aceptado
* **Fecha:** 2026-09-15
* **Autor:** Xavier Margalef Riestra
* **Contexto Técnico:** Elección de la capa de ejecución para la telemetría e inspección pasiva de red.

---

## 1. Contexto & Planteamiento del Problema
El sistema necesita monitorizar en tiempo real el tráfico de red, detectar escaneos de puertos (Nmap) y ataques de aplicación sin interferir en la latencia de las peticiones legítimas.

---

## 2. Alternativas Evaluadas (A vs. B)

### Opción A: Contenedorizado en Docker (`suricata-container`)
* **Descripción:** Desplegar Suricata como un servicio más dentro de `docker-compose.yml`.
* **Pros:** Facilidad de despliegue y aislamiento de dependencias.
* **Contras:** Dificultad para inspeccionar el tráfico nativo de las interfaces de red físicas del Host (e.g., `eth0`) y la necesidad de ejecutar el contenedor con privilegios elevados (`--net=host` y `--cap-add=NET_ADMIN`), anulando el beneficio del aislamiento en contenedores.

### Opción B: Instalación Nativa sobre Ubuntu Server 24.04 (Host Mode) — [Elegida]
* **Descripción:** Ejecutar Suricata como daemon del sistema (`systemd`) directamente en el OS base.
* **Pros:**
  1. Inspección en modo promiscuo directo sobre la interfaz física (`AF_PACKET` / `eBPF`).
  2. Captura completa de vectores de ataque dirigidos al servicio SSH (puerto 22), al daemon de Docker y al tráfico HTTP/S.
  3. Evita la sobrecarga de traducción de direcciones de red (NAT) que introducen las interfaces virtuales veth de Docker.
* **Contras:** Requiere gestión de paquetes y dependencias directamente sobre el sistema operativo Host.

---

## 3. Decisión Final
Se selecciona la **Opción B**. Suricata se ejecutará como proceso nativo del Host para garantizar visión total de la telemetría de red, registrando alertas unificadas en formato JSON en `/var/log/suricata/eve.json`.
