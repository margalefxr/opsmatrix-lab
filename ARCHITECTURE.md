# OpsMatrix Lab Architecture: Manual CLI vs. Declarative Compose

Este documento define la transición arquitectónica y la equivalencia operativa entre el despliegue manual y el modelo declarativo en capas.

## 1. Equivalencia Operativa
- Redes: `docker network create` vs bloques `networks:` con `internal: true`.
- Despliegue: `docker run` vs manifiestos unificados con volúmenes y múltiples redes (*dual-homed*).

## 2. Referencia de Configuración
La arquitectura se organiza en capas de Perímetro (`frontend_net`) y Servicios aislados (`backend_net`).
