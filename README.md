# OpsMatrix Lab — Infraestructura defensiva por capas

**Autor:** Xavier Margalef Riestra
**Módulos:** MF0488 (despliegue y hardening) · MF0489 (PKI, HTTPS y monitorización)
**Áreas:** Blue Team · Hardening · Segmentación de red · PKI · IDS · GRC

Laboratorio que simula el portal de una gestoría. La web es mínima a propósito. El trabajo está en los controles de alrededor: HTTPS con una CA propia, un proxy como única entrada, una base de datos sin salida a internet y un IDS vigilando la red.

![Arquitectura final](docs/mf0489/arquitectura-final.png)

## Entrega MF0489 (ExP 89)

| Fase | Pts | Documento |
|---|---|---|
| 1. Arquitectura con HTTPS | 0,50 | [fase1-arquitectura.md](docs/mf0489/fase1-arquitectura.md) |
| 2. PKI con OpenSSL | 3,00 | [fase2-pki.md](docs/mf0489/fase2-pki.md) |
| 3. HTTPS con Nginx y Docker | 4,00 | [fase3-https-docker.md](docs/mf0489/fase3-https-docker.md) |
| 4. Auditoría TLS y monitorización | 2,50 | [fase4-auditoria-tls-monitorizacion.md](docs/mf0489/fase4-auditoria-tls-monitorizacion.md) · incluye las [evidencias pedidas en el feedback del MF0488](docs/mf0489/fase4-auditoria-tls-monitorizacion.md#evidencias-pedidas-en-el-feedback-del-mf0488) |
| 5. Entrega final | — | [fase5-entrega-final.md](docs/mf0489/fase5-entrega-final.md) |
| Guía de despliegue y recuperación | — | [guia-despliegue.md](docs/mf0489/guia-despliegue.md) |
| Evidencias (salidas reales) | — | [`evidencias/`](docs/mf0489/evidencias/): `fase2/`, `fase3/`, `fase4/`, `fase5/`, `extras/` |
| Extras (criterio, CVE de Flask, revocación, inventario) | — | [extras.md](docs/mf0489/extras.md) |
| Pasos y dificultades | — | [WORKLOG.md](docs/mf0489/WORKLOG.md) |

Las fases 1-4 empiezan con la tabla de criterios de la rúbrica y dónde está la evidencia de cada uno. Lo que dicen los docs está comprobado contra el código en [`coherencia-docs-codigo.txt`](docs/mf0489/evidencias/fase5/coherencia-docs-codigo.txt).

Lo del MF0488 sigue en [`docs/WORKLOG.md`](docs/WORKLOG.md) y [`docs/adr/`](docs/adr/). Es la foto de entonces y no lo he reescrito. Lo que ya no es cierto (por ejemplo "solo TLS 1.3", el WAF o las reglas de Nmap) está en [correcciones-mf0488.md](docs/correcciones-mf0488.md), con lo que hay hoy y su evidencia.

## Cómo funciona

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
| Versiones fijas | Dependencias de Python exactas (`==`), también las transitivas. Imágenes por rama (`nginx:1.28-alpine`, `mariadb:10.11`, `python:3.12-slim`): no cambian de versión mayor, pero sí reciben parches |

## Cómo lo he hecho

| | |
|---|---|
| **Método** | MSA / lean: lo mínimo que funcione y se pueda comprobar. Tablas antes que texto, una decisión = un motivo |
| **Pruebas** | Primero en local, luego en la VM. Pruebas positivas y negativas (lo que tiene que fallar, falla). Matriz completa en la [Fase 5](docs/mf0489/fase5-entrega-final.md#cómo-he-probado-qa) |
| **Trazabilidad** | Cada paso y cada problema en el [WORKLOG](docs/mf0489/WORKLOG.md). Las salidas de las pruebas son reales y están en [`evidencias/`](docs/mf0489/evidencias/) |
| **CI** | [GitHub Actions](.github/workflows/checks.yml) repite en cada push `shellcheck` (todos los `.sh`), `docker compose config`, `py_compile`, `pip-audit` y `detect-secrets`. Con permisos de solo lectura y la acción fijada por commit |
| **IA** | Ver abajo |

### Uso de la IA

| | |
|---|---|
| Qué hizo la IA | Preparar scripts y comandos, proponer la estructura de los docs y revisar coherencia |
| Qué hice yo | Ejecutar todo en mi laboratorio, pegar las salidas reales y decidir. Lo que no entendía, lo pregunté hasta poder explicarlo |
| Cómo lo verifiqué | Nada se documenta sin una salida real. Lo propuesto se probaba primero en local y luego en la VM |
| Qué no le pasé | Ninguna clave privada, contraseña ni `.env`. Solo salidas y archivos públicos |
| Paquetes sugeridos | Comprobados en PyPI y con `pip-audit` antes de usarlos. Las IA a veces inventan nombres de paquetes y alguien los registra con malware (*slopsquatting*) |

## Extra: más allá de la rúbrica

Temas que hoy pesan en el sector y que he aplicado al laboratorio. El criterio para elegirlos y el detalle de cada uno están en [extras.md](docs/mf0489/extras.md).

| Tema | Qué he hecho | Por qué importa |
|---|---|---|
| Software de terceros (supply chain) | `pip-audit` encontró CVE-2026-27205 en Flask 3.0.3. No era explotable aquí (no uso `session` ni caché), pero subí a 3.1.3, fijé todas las dependencias y generé el SBOM | El Cyber Resilience Act (UE 2024/2847) pedirá SBOM y gestión de vulnerabilidades. ISO 27001 A.5.21 |
| Criptografía post-cuántica | Nginx y OpenSSL 3.5 ya negocian `X25519MLKEM768` | Riesgo "harvest now, decrypt later". La hoja de ruta PQC de la UE pide empezar la migración en 2026 |
| Vida de los certificados | Certificado de 1 año y fecha de renovación anotada | El CA/B Forum baja los certificados públicos a 47 días en 2029: renovar a mano deja de ser viable (ACME) |
| Detección como código | Reglas de Suricata en git y probadas con una captura antes de desplegarlas | Una regla que no se ha probado puede no saltar nunca (me pasó con `flags:S`) |
| Huella TLS (JA4) | Suricata la registra en `eve.json` sin descifrar nada | Permite reconocer clientes o malware por cómo saludan en TLS |
| Secretos | `detect-secrets`: 0 hallazgos. Historial revisado | Las claves subidas a git son una de las fugas más comunes |
| Revocación (CRL) | Revoqué un certificado de prueba como "clave comprometida", publiqué la CRL y el cliente lo rechaza (`error 23`). Procedimiento si se filtra una clave | Let's Encrypt apagó OCSP en agosto de 2025: la revocación vuelve a ir por CRL |
| Inventario criptográfico | Tabla con cada clave, algoritmo, caducidad y si aguanta la post-cuántica. Hallazgo: TLS ya es post-cuántico, SSH todavía no | Es el primer paso de cualquier migración post-cuántica |

Evidencias: [`supply-chain.txt`](docs/mf0489/evidencias/extras/supply-chain.txt), [`sbom-app.cdx.json`](docs/mf0489/evidencias/extras/sbom-app.cdx.json) y [`pki-revocacion.txt`](docs/mf0489/evidencias/extras/pki-revocacion.txt).

## Desplegar

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/deploy.sh        # en la VM, con los certificados ya en /etc/ssl/
bash scripts/check-vm.sh      # comprobar el servidor
bash scripts/check-mac.sh     # comprobar desde el cliente
```

Paso a paso, copias de seguridad y recuperación: [guía de despliegue](docs/mf0489/guia-despliegue.md).

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
├── scripts/                      ← deploy, backup-db, check-vm, check-mac, fase4-*, feedback-mf0488-vm, pki-revocacion y sync_ops (MF0488, no se usa)
└── docs/mf0489/                  ← fases, guía, WORKLOG y evidencias
```

Mantengo la estructura por capas del MF0488. Equivalencia con la estructura orientativa del enunciado:

| Enunciado | Aquí |
|---|---|
| `nginx/default.conf` | `layer2-perimeter/nginx/default.conf` |
| `pki/` | `layer2-perimeter/pki/` |
| `suricata/local.rules` | `layer1-telemetry/suricata/rules/local.rules` |
| `docs/mf0489/evidencias/fase2/` … `fase5/` | Igual, más `extras/` |

## Lo que no está en el repo

`ca.key`, `servidor.key`, `.env`, copias de la BBDD y la OVA. Lo impide el [`.gitignore`](.gitignore).

## Normativa

| Referencia | Dónde se aplica |
|---|---|
| ENS (RD 311/2022) mp.com.1-4 | Perímetro, cifrado en tránsito y redes separadas |
| ENS op.mon.1 / op.exp.8 | Suricata y logs de Nginx |
| ISO 27001 A.8.24 | Criptografía y custodia de claves |
| ISO 27001 A.8.22 | Segregación de redes |
| ISO 27001 A.5.17 | Contraseñas fuera del código |
| RGPD art. 32 | Cifrado de los datos de clientes en tránsito |

## Repositorios relacionados

- **[MSA-Playbook](https://github.com/margalefxr/MSA-Playbook)** — metodología ofensiva. OpsMatrix aplica los controles que frenan esos mismos vectores.
- **[CyberOps-Portfolio](https://github.com/margalefxr/CyberOps-Portfolio)** — laboratorios y auditorías donde aplico esa metodología.
