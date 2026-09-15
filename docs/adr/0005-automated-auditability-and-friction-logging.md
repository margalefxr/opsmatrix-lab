# ADR 0005: Trazabilidad Automática de Cambios y Registro de Fricción Técnica

* **Estatus:** Aceptado
* **Fecha:** 2026-09-15
* **Autor:** Xavier Margalef Riestra
* **Contexto Técnico:** Automatización de la bitácora de auditoría y gestión de errores de entorno.

---

## 1. Contexto & Planteamiento del Problema
El registro manual de cambios, decisiones y errores de debugging en `WORKLOG.md` propicia omisiones de contexto y reduce la precisión del rastro forense durante el desarrollo.

---

## 2. Decisión
1. Implementar un hook `pre-commit` en Git que analice las modificaciones del índice y actualice de forma transparente `docs/WORKLOG.md` antes de consolidar el commit.
2. Estandarizar la captura de errores de consola/entorno vía script dedicado (`capture_debug.sh`).

---

## 3. Consecuencias
* Trazabilidad 100% garantizada sin sobrecarga manual para el operador.
* Inmutabilidad del rastro temporal de desarrollo y debugging para evaluación técnica y auditoría GRC.
