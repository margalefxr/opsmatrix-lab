# OpsMatrix Lab — Infraestructura defensiva por capas

**Autor:** Xavier Margalef Riestra
**Módulos:** MF0488 (despliegue y hardening) · MF0489 (PKI, HTTPS y monitorización)

Laboratorio que simula el portal de una gestoría. Lo importante no es la web, sino los controles que tiene alrededor: HTTPS con una CA propia, un proxy como única entrada, una base de datos sin salida a internet y un IDS vigilando la red.

![Arquitectura final](docs/mf0489/arquitectura-final.png)

## Cómo funciona

```
Cliente ──HTTPS 443──▶ Nginx ──HTTP──▶ App Flask ──SQL──▶ MariaDB
        ──HTTP 80 ──▶ (301)  frontend_net        backend_net (internal)
                   ▲
        Suricata vigila enp2s0
```

| Pieza | Qué hace |
|---|---|
| **CA propia** (fuera de la VM) | Firma el certificado de `portal.opsmatrix.test`. Su clave nunca entra en la VM |
| **Nginx** (`reverse-proxy`) | Única entrada. Redirige 80 → 443, termina TLS 1.2/1.3 y pasa la petición a la app |
| **App** (Flask) | Guarda cada visita en MariaDB y enseña el total. Corre como `nobody`, sin puertos abiertos |
| **MariaDB** (`db`) | En `backend_net` (`internal: true`): sin salida a internet y sin acceso desde fuera |
| **Suricata** | IDS en la interfaz `enp2s0`. Regla propia para las conexiones HTTPS |
| **SSH** | Solo con clave Ed25519 |

## Puertos

| Servicio | Puerto | ¿Abierto en la VM? |
|---|---|---|
| OpenSSH | 22 | ✅ solo con clave |
| Nginx | 80, 443 | ✅ (80 solo redirige) |
| App | 5000 | ❌ solo dentro de Docker |
| MariaDB | 3306 | ❌ solo en `backend_net` |

## Principios

| Principio | Cómo se aplica aquí |
|---|---|
| Defensa en profundidad | Varias capas: TLS, proxy como única entrada, redes separadas, IDS y logs |
| Mínimo privilegio | Nginx no ve la BBDD, la app corre como `nobody`, montajes `:ro`, claves con 600 |
| Segmentación | `frontend_net` y `backend_net` (`internal: true`), solo 80/443 publicados |
| Secretos fuera del código | `.env` y claves fuera de git. La CA, fuera de la VM |
| Configuración como código | Compose, Nginx, reglas de Suricata y SSH versionados en el repo |
| Observabilidad | Suricata en la red + log de Nginx con versión TLS, cruzados por IP y puerto |
| Reproducible | `deploy.sh` + `check-*.sh`. Comprobado tras reiniciar la VM |
| Versiones fijas | `nginx:1.28-alpine`, `mariadb:10.11`, `Flask==3.0.3`, `PyMySQL==1.1.1` |

## Cómo lo he hecho

| | |
|---|---|
| **Método** | MSA / lean: lo mínimo que funcione y se pueda comprobar. Tablas antes que texto, una decisión = un motivo |
| **Pruebas** | Primero en local, luego en la VM. Pruebas positivas y negativas (lo que tiene que fallar, falla). Matriz completa en la [Fase 5](docs/mf0489/fase5-entrega-final.md#cómo-he-probado-qa) |
| **Trazabilidad** | Cada paso y cada problema en el [WORKLOG](docs/mf0489/WORKLOG.md). Las salidas de las pruebas son reales y están en [`evidencias/`](docs/mf0489/evidencias/) |
| **IA** | Me he apoyado en un asistente de IA para preparar scripts y revisar la documentación. Los comandos los he ejecutado yo en mi laboratorio y las decisiones las he revisado una a una |

## Desplegar

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/deploy.sh        # en la VM, con los certificados ya en /etc/ssl/
bash scripts/check-vm.sh      # comprobar el servidor
bash scripts/check-mac.sh     # comprobar desde el cliente
```

Paso a paso, copias de seguridad y recuperación: [guía de despliegue](docs/mf0489/guia-despliegue.md).

## Documentación MF0489

| Fase | Pts | Documento |
|---|---|---|
| 1. Arquitectura con HTTPS | 0,50 | [fase1-arquitectura.md](docs/mf0489/fase1-arquitectura.md) |
| 2. PKI con OpenSSL | 3,00 | [fase2-pki.md](docs/mf0489/fase2-pki.md) |
| 3. HTTPS con Nginx y Docker | 4,00 | [fase3-https-docker.md](docs/mf0489/fase3-https-docker.md) |
| 4. Auditoría TLS y monitorización | 2,50 | [fase4-auditoria-tls-monitorizacion.md](docs/mf0489/fase4-auditoria-tls-monitorizacion.md) |
| 5. Entrega final | — | [fase5-entrega-final.md](docs/mf0489/fase5-entrega-final.md) |

Cada documento empieza con la tabla de criterios de la rúbrica y dónde está la evidencia de cada uno.
| Pasos y dificultades | [WORKLOG.md](docs/mf0489/WORKLOG.md) |

Lo del MF0488 sigue en [`docs/WORKLOG.md`](docs/WORKLOG.md) y [`docs/adr/`](docs/adr/). Es la foto de entonces: donde no coincida con lo de arriba (por ejemplo "solo TLS 1.3" o el compose de `layer3-services/docker`), manda lo del MF0489.

## Estructura

```text
opsmatrix-lab/
├── docker-compose.yml            ← proxy + app + db
├── .env.example                  ← plantilla (el .env real no se sube)
├── layer1-telemetry/suricata/    ← local.rules y override de systemd
├── layer2-perimeter/
│   ├── nginx/default.conf
│   ├── pki/                      ← ca.crt, servidor.crt, servidor.csr, servidor.ext (públicos)
│   └── ssh/00-opsmatrix.conf     ← SSH solo con clave
├── layer3-services/app/          ← app Flask + Dockerfile
├── scripts/                      ← deploy, backup-db, check-vm, check-mac, fase4-* y sync_ops (MF0488)
└── docs/mf0489/                  ← fases, guía, WORKLOG y evidencias
```

## Lo que no está en el repo

`ca.key`, `servidor.key`, `.env`, copias de la BBDD y la OVA. Lo impide el [`.gitignore`](.gitignore).

## Normativa

| Referencia | Dónde se aplica |
|---|---|
| ENS (RD 311/2022) mp.com.1-3 | Redes separadas y cifrado en tránsito |
| ENS op.mon.1 / op.exp.8 | Suricata y logs de Nginx |
| ISO 27001 A.8.24 | Criptografía y custodia de claves |
| ISO 27001 A.8.22 | Segregación de redes |
| ISO 27001 A.5.17 | Contraseñas fuera del código |
| RGPD art. 32 | Cifrado de los datos de clientes en tránsito |

## Repositorios relacionados

- **[MSA-Playbook](https://github.com/margalefxr/MSA-Playbook)** — metodología ofensiva. OpsMatrix aplica los controles que frenan esos mismos vectores.
- **[CyberOps-Portfolio](https://github.com/margalefxr/CyberOps-Portfolio)** — laboratorios y auditorías donde aplico esa metodología.
