# ADR 0004: Motor de Reglas y Telemetría Pasiva en Suricata NIDS

* **Estatus:** Aceptado
* **Fecha:** 2026-09-15
* **Autor:** Xavier Margalef Riestra
* **Contexto Técnico:** Definición de firmas de red para la monitorización de tráfico en la interfaz física del host.

---

## 1. Contexto & Planteamiento del Problema
Se requiere inspeccionar el tráfico entrante a nivel de paquete antes o durante su procesamiento por la pila de red del kernel, generando alertas estructuradas en `eve.json` sin alterar el rendimiento de los contenedores.

---

## 2. Decisión & Firma de Reglas Custom
Se implementa una política de firmas de red en `layer1-telemetry/suricata/rules/local.rules` que audita:
1. **Tráfico ICMP Echo Request (`sid:1000001`):** Captura sondeos ICMP de descubrimiento de red.
2. **Escaneos de Seguridad HTTP (`sid:1000002`):** Identifica peticiones perimetrales que utilicen agentes de usuario asociados a herramientas de pentesting/reconocimiento (`Nmap`, `Nikto`, `sqlmap`).

---

## 3. Consecuencias & Salida Forense
Todas las coincidencias de reglas emitirán metadatos JSON completos hacia `/var/log/suricata/eve.json`.
