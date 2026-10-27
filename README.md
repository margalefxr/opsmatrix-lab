# OpsMatrix Lab — Infraestructura defensiva por capas

**Autor:** Xavier Margalef Riestra
**Módulos:** MF0488 (despliegue y hardening) · MF0489 (PKI, HTTPS y monitorización)
**Áreas:** Blue Team · Hardening · Segmentación de red · PKI · IDS · GRC

## Contexto

OpsMatrix es una gestoría ficticia: lleva la contabilidad, las nóminas y los trámites fiscales de autónomos y pequeñas empresas. Por su portal pasan datos personales y económicos de sus clientes (DNI, nóminas, modelos de Hacienda), así que lo que de verdad importa no es la web en sí —es mínima a propósito— sino todo lo que la protege: que los datos viajen cifrados, que haya una sola puerta de entrada, que la base de datos no se vea desde fuera y que quede rastro de quién toca la red.

Eso es lo que monto y pruebo en este laboratorio: HTTPS con una CA mía, Nginx como único punto de entrada, una base de datos sin salida a internet y un IDS vigilando el tráfico.

![Arquitectura final](docs/mf0489/arquitectura-final.png)

## Entrega MF0489 (ExP 89)

| Fase | Pts | Documento |
|---|---|---|
| 1. Arquitectura con HTTPS | 0,50 | [fase1-arquitectura.md](docs/mf0489/fase1-arquitectura.md) |
| 2. PKI con OpenSSL | 3,00 | [fase2-pki.md](docs/mf0489/fase2-pki.md) |
| 3. HTTPS con Nginx y Docker | 4,00 | [fase3-https-docker.md](docs/mf0489/fase3-https-docker.md) |
| 4. Auditoría TLS y monitorización | 2,50 | [fase4-auditoria-tls-monitorizacion.md](docs/mf0489/fase4-auditoria-tls-monitorizacion.md) · también las [evidencias que me pidieron en el feedback del MF0488](docs/mf0489/fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| 5. Entrega final | — | [fase5-entrega-final.md](docs/mf0489/fase5-entrega-final.md) |
| Guía de despliegue y recuperación | — | [guia-despliegue.md](docs/mf0489/guia-despliegue.md) |
| Evidencias (salidas reales) | — | [`evidencias/`](docs/mf0489/evidencias/): `fase2/`, `fase3/`, `fase4/`, `fase5/`, `extras/` |
| Extras (CVE de Flask, revocación, inventario de claves) | — | [extras.md](docs/mf0489/extras.md) |
| Validación desde fuera (Kali) | — | [validacion-ofensiva.md](docs/mf0489/validacion-ofensiva.md) |
| Pasos y dificultades | — | [WORKLOG.md](docs/mf0489/WORKLOG.md) |

Cada fase (de la 1 a la 4) empieza con los criterios de la rúbrica y dónde está la prueba de cada uno. Además he cruzado lo que digo en los documentos con el código: [`coherencia-docs-codigo.txt`](docs/mf0489/evidencias/fase5/coherencia-docs-codigo.txt).

Lo del MF0488 sigue en [`docs/WORKLOG.md`](docs/WORKLOG.md) y [`docs/adr/`](docs/adr/). No lo he tocado porque es lo que entregué entonces. Algunas cosas de ahí ya no son verdad (decía "solo TLS 1.3", hablaba de un WAF y de reglas para Nmap), así que las he apuntado en [correcciones-mf0488.md](docs/correcciones-mf0488.md) con cómo está ahora y la prueba.

## Cómo funciona

| Pieza | Qué hace |
|---|---|
| **CA propia** (fuera de la VM) | Firma el certificado de `portal.opsmatrix.test`. Su clave nunca entra en la VM |
| **Nginx** (`reverse-proxy`) | Es la única entrada. Redirige del 80 al 443, termina TLS 1.2/1.3 y le pasa la petición a la app |
| **App** (Flask) | Guarda cada visita en MariaDB y muestra el total. Se ejecuta como `nobody` y no publica ningún puerto |
| **MariaDB** (`db`) | Está en `backend_net` (`internal: true`): no sale a internet y no se llega desde fuera |
| **Suricata** | IDS en la interfaz `enp2s0`, con una regla mía para las conexiones HTTPS |
| **SSH** | Solo con clave Ed25519 |

## Puertos

| Servicio | Puerto | ¿Abierto en la VM? |
|---|---|---|
| OpenSSH | 22 | ✅ solo con clave |
| Nginx | 80, 443 | ✅ (el 80 solo redirige) |
| App | 5000 | ❌ solo dentro de Docker |
| MariaDB | 3306 | ❌ solo en `backend_net` |

## Principios

| Principio | Cómo lo aplico |
|---|---|
| Defensa en profundidad | Varias capas: TLS, proxy como única entrada, redes separadas, IDS y logs |
| Mínimo privilegio | Nginx no ve la BBDD, la app se ejecuta como `nobody`, montajes `:ro` y claves con 600 |
| Segmentación | `frontend_net` y `backend_net` (`internal: true`), y solo publico el 80 y el 443 |
| Secretos fuera del código | `.env` y claves fuera de git. La CA, fuera de la VM |
| Configuración como código | Compose, Nginx, reglas de Suricata y SSH están en el repo |
| Observabilidad | Suricata en la red y el log de Nginx con la versión TLS. Los cruzo por IP y puerto |
| Reproducible | [Guía](docs/mf0489/guia-despliegue.md) + `deploy.sh` + `check-*.sh`. Lo he montado desde cero con un clon limpio de GitHub, `.env` y BBDD nuevos ([`prueba-limpia-vm.txt`](docs/mf0489/evidencias/fase5/prueba-limpia-vm.txt)), y la PKI con claves nuevas ([`replica-desde-cero.txt`](docs/mf0489/evidencias/fase5/replica-desde-cero.txt)) |
| Validado, no supuesto | Cada control lo pruebo después de montarlo, y además desde fuera con Kali. Lo que no puedo demostrar con una salida, lo digo |
| Versiones fijas | Las dependencias de Python van con versión exacta (`==`), también las que arrastra Flask. Las imágenes van por rama (`nginx:1.28-alpine`, `mariadb:10.11`, `python:3.12-slim`): no cambian de versión mayor, pero los parches sí entran |

## Cómo lo he hecho

| | |
|---|---|
| **Método** | MSA / lean: lo mínimo que funcione y que se pueda comprobar. Tablas antes que párrafos, y cada decisión con su motivo |
| **Pruebas** | No doy un control por bueno hasta que lo pruebo de tres maneras: que funciona, que lo que tiene que fallar falla (y al lado, otra prueba que demuestra que el comando sí funciona), y desde fuera, con Kali, que un extraño sin mi CA se queda en la puerta. La lista completa está en la [Fase 5](docs/mf0489/fase5-entrega-final.md#cómo-he-probado-qa) y la de fuera en la [validación desde Kali](docs/mf0489/validacion-ofensiva.md) |
| **Trazabilidad** | Cada paso y cada problema están en el [WORKLOG](docs/mf0489/WORKLOG.md). Las salidas de las pruebas son reales y están en [`evidencias/`](docs/mf0489/evidencias/) |
| **CI** | Con [GitHub Actions](.github/workflows/checks.yml), en cada push se repiten `shellcheck` (todos los `.sh`), `docker compose config`, `py_compile`, `pip-audit` y `detect-secrets`. Con permisos de solo lectura y la acción fijada por commit |
| **IA** | Abajo |

### Uso de la IA

| | |
|---|---|
| Para qué la he usado | QA y testing: scripts para comprobar que lo que había montado estaba bien, pruebas internas en un entorno aparte (las evidencias que lo dicen en la cabecera: "entorno de pruebas"), y revisar la lógica y la coherencia de todo, comparándolo con la rúbrica |
| Qué he hecho yo | Montar y lanzar en mi laboratorio (Mac y VM) todo lo que toca la CA, la VM y la red, pegar las salidas reales y decidir. Lo que no entendía lo preguntaba hasta poder explicarlo |
| Cómo lo he comprobado | No documento nada sin una salida real. Los cambios de configuración los probaba primero en el entorno de pruebas y luego en la VM |
| Qué no le he pasado | Ninguna clave privada, contraseña ni `.env`. Solo salidas y archivos públicos |
| Paquetes que me sugería | Los comprobaba con `pip-audit` (que los busca en PyPI) antes de usarlos. A veces las IA se inventan nombres de paquetes y alguien los registra con malware (*slopsquatting*) |

## Extra: más allá de la rúbrica

Son temas que ahora mismo pesan en el sector y que he querido probar en el laboratorio. Por qué elegí estos y el detalle de cada uno está en [extras.md](docs/mf0489/extras.md).

| Tema | Qué he hecho | Por qué importa |
|---|---|---|
| Software de terceros (supply chain) | `pip-audit` encontró CVE-2026-27205 en Flask 3.0.3. Aquí no se podía explotar (no uso `session` ni caché), pero subí a 3.1.3, fijé todas las dependencias y saqué el SBOM | El Cyber Resilience Act (UE 2024/2847) va a pedir SBOM y gestión de vulnerabilidades. ISO 27001 A.5.21 |
| Criptografía post-cuántica | Nginx y OpenSSL 3.5 ya negocian `X25519MLKEM768` | Por el riesgo de "harvest now, decrypt later". La hoja de ruta PQC de la UE pide empezar la migración en 2026 |
| Vida de los certificados | Certificado de 1 año, con la fecha de renovación apuntada | El CA/B Forum baja los certificados públicos a 47 días en 2029: renovarlos a mano deja de tener sentido (ACME) |
| Detección como código | Las reglas de Suricata están en git. La nueva (1000003) la probé con una captura antes de llevarla a la VM | Una regla sin probar puede no saltar nunca (me pasó con `flags:S`) |
| Huella TLS (JA4) | Suricata la guarda en `eve.json` sin descifrar nada | Sirve para reconocer clientes o malware por cómo saludan en TLS |
| Secretos | `detect-secrets`: 0 hallazgos. También he revisado el historial | Las claves subidas a git son una de las fugas más típicas |
| Revocación (CRL) | Revoqué un certificado de prueba como "clave comprometida", publiqué la CRL y el cliente lo rechaza (`error 23`). Y escribí qué hacer si se filtra una clave | Let's Encrypt apagó OCSP en agosto de 2025: la revocación vuelve a ir por CRL |
| Inventario criptográfico | Una tabla con cada clave, su algoritmo, cuándo caduca y si aguantaría la post-cuántica. Lo que salió: TLS ya es post-cuántico, SSH todavía no | Es el primer paso para cualquier migración post-cuántica |

Evidencias: [`supply-chain.txt`](docs/mf0489/evidencias/extras/supply-chain.txt), [`sbom-app.cdx.json`](docs/mf0489/evidencias/extras/sbom-app.cdx.json) y [`pki-revocacion.txt`](docs/mf0489/evidencias/extras/pki-revocacion.txt).

## Desplegar

Antes hace falta tu propia CA y tus certificados en `/etc/ssl/` de la VM. Cada uno crea los suyos con la [guía §2](docs/mf0489/guia-despliegue.md#2-pki-una-vez-con-tus-propias-claves); los míos no hacen falta.

En la VM:

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/deploy.sh        # crea el .env con contraseñas nuevas y levanta los 3 contenedores
bash scripts/check-vm.sh      # comprueba el servidor
```

En el equipo cliente, donde tengas la CA (antes, cambia `IP` y `CA_DIR` arriba del script):

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/check-mac.sh     # 301, 200 con la CA, exit 60 sin ella, TLS 1.1 rechazado
```

Lo he probado así desde cero ([`prueba-limpia-vm.txt`](docs/mf0489/evidencias/fase5/prueba-limpia-vm.txt), [`prueba-limpia-mac.txt`](docs/mf0489/evidencias/fase5/prueba-limpia-mac.txt)). El paso a paso, las copias de seguridad y la recuperación están en la [guía de despliegue](docs/mf0489/guia-despliegue.md).

## Estructura

```text
opsmatrix-lab/
├── docker-compose.yml            ← proxy + app + db
├── .env.example                  ← plantilla (el .env real no se sube)
├── .github/workflows/checks.yml  ← comprobaciones automáticas (CI)
├── layer1-telemetry/suricata/    ← local.rules y override de systemd
├── layer2-perimeter/
│   ├── nginx/default.conf
│   ├── pki/                      ← ca.crt, servidor.crt/.csr/.ext, ca.crl, ca.cnf (todo público)
│   └── ssh/00-opsmatrix.conf     ← SSH solo con clave
├── layer3-services/app/          ← app Flask + Dockerfile
├── scripts/                      ← deploy, backup-db, check-vm, check-mac, fase4-*, validacion-atacante, feedback-mf0488-vm, pki-revocacion y sync_ops (del MF0488, ya no lo uso)
└── docs/mf0489/                  ← fases, guía, WORKLOG y evidencias
```

He mantenido la estructura por capas del MF0488. Así encaja con la estructura orientativa del enunciado:

| Enunciado | Aquí |
|---|---|
| `nginx/default.conf` | `layer2-perimeter/nginx/default.conf` |
| `pki/` | `layer2-perimeter/pki/` |
| `suricata/local.rules` | `layer1-telemetry/suricata/rules/local.rules` |
| `docs/mf0489/evidencias/fase2/` … `fase5/` | Igual, y además `extras/` |

## Lo que no está en el repo

`ca.key`, `servidor.key`, `.env`, las copias de la BBDD y la OVA. El [`.gitignore`](.gitignore) no deja subirlos.

## Normativa

| Referencia | Dónde se aplica |
|---|---|
| ENS (RD 311/2022) mp.com.1-4 | Perímetro, cifrado en tránsito y redes separadas |
| ENS op.mon.1 / op.exp.8 | Suricata y logs de Nginx |
| ISO 27001 A.8.24 | Criptografía y custodia de claves |
| ISO 27001 A.8.22 | Segregación de redes |
| ISO 27001 A.5.17 | Contraseñas fuera del código |
| RGPD art. 32 | Cifrado en tránsito de los datos de clientes |

## Repositorios relacionados

- **[MSA-Playbook](https://github.com/margalefxr/MSA-Playbook)**: mi metodología ofensiva. En OpsMatrix pongo los controles que frenan esos mismos vectores.
- **[CyberOps-Portfolio](https://github.com/margalefxr/CyberOps-Portfolio)**: laboratorios y auditorías donde aplico esa metodología.
