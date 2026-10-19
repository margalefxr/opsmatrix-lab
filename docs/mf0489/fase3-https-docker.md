# Fase 3 — HTTPS con Nginx reverse proxy y Docker

Publico el portal de OpsMatrix por `https://portal.opsmatrix.test` con el certificado de la Fase 2. Nginx es la única entrada: termina TLS y pasa la petición a la app, que guarda cada visita en MariaDB. Todas las salidas son reales, del 19/10/2026.

## Resumen

| Requisito | Resultado | Evidencia |
|---|---|---|
| Acceso por `https://portal.opsmatrix.test` en el 443 | ✅ La página carga y el contador sube | [§6](#6-pruebas-desde-el-cliente-mac) |
| Nginx usa `servidor.crt` y `servidor.key` de la Fase 2 | ✅ Montados `:ro` desde `/etc/ssl/` | [§4](#4-certificados-y-permisos) |
| Verificación contra la CA del laboratorio, sin `-k` | ✅ `Verification: OK` · `curl --cacert` | [§6](#6-pruebas-desde-el-cliente-mac) |
| HTTP → HTTPS | ✅ `301` con `Location: https://…` | [§6](#6-pruebas-desde-el-cliente-mac) |
| Nginx → app → MariaDB | ✅ Sin 502; las visitas se guardan | [§7](#7-aplicación-y-persistencia) |
| App y BBDD sin puertos publicados | ✅ Solo 22, 80 y 443 en el host | [§2](#2-servicios-redes-y-puertos-antes-y-después) |
| Sin claves ni contraseñas en GitHub | ✅ Secretos en `.env`, claves en `/etc/ssl/` | [§3](#3-decisiones) |

## 1. Arquitectura y dónde termina TLS

Diagrama completo en [Fase 1](fase1-arquitectura.md#diagrama).

```
Mac (cliente, ca.crt) ──HTTPS :443──▶ reverse-proxy ──HTTP :5000──▶ app ──SQL :3306──▶ db
                      ──HTTP  :80 ──▶   (301)          frontend_net        backend_net (internal)
```

| Tramo | Cifrado | Por qué |
|---|---|---|
| Cliente → Nginx | ✅ TLS 1.2 / 1.3 | Es el único tramo que sale de la VM y pasa por la red del laboratorio |
| Nginx → app | ❌ HTTP | Bridge interno de Docker, no sale del host |
| app → MariaDB | ❌ MySQL en claro | `backend_net` es `internal: true`: sin salida a internet ni acceso desde fuera |

**TLS termina en Nginx.** Con datos personales reales cifraría también los tramos internos (Zero Trust), pero aquí queda documentado como límite aceptado.

## 2. Servicios, redes y puertos antes y después

**Antes (Actividad 8, 10:33 UTC):**

| Contenedor | Estado | Problema |
|---|---|---|
| `opsmatrix-web` (`nginx:alpine`) | Up, publicaba 80/443 | Config por defecto de la imagen, sin TLS ni app. `curl http://localhost/` → `Connection reset by peer` |
| `opsmatrix-db` (`mariadb:10.11`) | `Restarting` cada 60 s | `Database is uninitialized and password option is not specified`: no había `.env` |
| `layer3-services/docker/docker-compose.yml` | No se usaba | Tenía contraseñas escritas en claro |

**Después:**

| Servicio | Imagen | Redes | Puerto interno | Publicado en el host |
|---|---|---|---|---|
| `reverse-proxy` | `nginx:1.28-alpine` | `frontend_net` | 80, 443 | ✅ `0.0.0.0:80`, `0.0.0.0:443` |
| `app` | `opsmatrix-lab-app` (Flask) | `frontend_net` + `backend_net` | 5000 (`expose`) | ❌ |
| `db` | `mariadb:10.11` | `backend_net` | 3306 | ❌ |

```
$ sudo ss -tulnp | grep -E ':(22|80|443|3306|5000)\b'
tcp LISTEN 0.0.0.0:80    docker-proxy
tcp LISTEN 0.0.0.0:22    sshd
tcp LISTEN 0.0.0.0:443   docker-proxy
```

Desde el Mac, `nc -zv 172.16.181.132 3306` y `… 5000` → `Connection refused`.

**Copia de seguridad previa** (sin `down -v`):

```
docker compose down          # sin -v: el volumen se conserva
sudo tar czf ~/backups/mariadb_data-2026-10-19.tgz -C /var/lib/docker/volumes/opsmatrix-lab_mariadb_data _data
-rw------- 1 root root 131 Oct 19 10:51 mariadb_data-2026-10-19.tgz
```

131 bytes = volumen vacío. MariaDB nunca llegó a inicializarse, así que no había datos que perder. Las configuraciones anteriores están en git (`604c5b2`): para volver atrás basta `git checkout main`.

## 3. Decisiones

| Decisión | Por qué A y no B |
|---|---|
| Nginx **nuevo** como reverse proxy | El anterior servía la página por defecto. No tenía nada que conservar |
| App mínima en Flask | Antes no había app real. Hace falta algo que use MariaDB para demostrar que la cadena completa funciona detrás del proxy |
| Nginx solo en `frontend_net` | No necesita la BBDD. Si comprometen Nginx, no llegan directo a MariaDB (mínimo privilegio) |
| `app` en las dos redes | Es el único puente entre web y datos |
| `expose` en la app, no `ports` | `expose` solo la deja visible dentro de Docker. La única entrada pública es Nginx |
| Imagen fijada `nginx:1.28-alpine` y `mariadb:10.11` | Versiones reproducibles, no lo que traiga `latest` ese día (supply chain) |
| Un solo `docker-compose.yml` en la raíz | Había dos y el de `layer3` no se usaba. Borrado para que la documentación coincida con lo que corre |
| Credenciales en `.env` (`chmod 600`, en `.gitignore`) generadas con `openssl rand -base64 24` | Lección del MF0488: compose con contraseñas escritas y `.env.example` sin usar |
| App con `USER nobody` | Si alguien explota la app, no es root dentro del contenedor |
| `server_tokens off` en 80 y 443 | No dar la versión exacta de Nginx a quien escanee |

### Preguntas de la Actividad 10

| Pregunta | Respuesta |
|---|---|
| ¿Qué hace `ports`? | Publica un puerto del contenedor en la IP del host (`"443:443"` = host:contenedor). Sin él, el servicio solo se ve dentro de Docker |
| ¿Para qué sirve cada `volume`? | `default.conf` → la config de Nginx del repo. `servidor.crt` → el certificado que presenta. `servidor.key` → la clave para el handshake. `mariadb_data` → los datos de la BBDD fuera del contenedor |
| ¿Qué significa `:ro`? | Solo lectura. Si comprometen Nginx no puede modificar su config ni sustituir el certificado |
| ¿Por qué `servidor.key` y no `ca.key`? | Nginx **demuestra** su identidad firmando el handshake con su clave privada. `ca.key` solo sirve para **emitir** certificados, y eso ya se hizo en el Mac. Quien verifica (el cliente) usa `ca.crt`, que es público |
| ¿Necesita el proxy la red de la BBDD? | No. Solo habla con la app. Conectarlo a `backend_net` ampliaría la superficie sin necesidad |

## 4. Certificados y permisos

| Archivo en la VM | Permisos | Dentro del contenedor |
|---|---|---|
| `/etc/ssl/private/servidor.key` | `600 root:root` | `/etc/nginx/certs/servidor.key` `:ro` |
| `/etc/ssl/certs/servidor.crt` | `644 root:root` | `/etc/nginx/certs/servidor.crt` `:ro` |
| `/etc/ssl/mf0489/ca.crt` | `644 root:root` | No se monta: Nginx no la necesita |
| `ca.key` | — | Solo en el Mac. Ni en la VM, ni en la imagen, ni en GitHub |

Nginx lee la clave aunque sea `600` porque su proceso maestro arranca como root y luego baja privilegios en los workers. La clave **no se copia en ninguna imagen** (`COPY`): se monta en tiempo de ejecución.

Verificación previa (Fase 2): `openssl verify -CAfile /etc/ssl/mf0489/ca.crt -purpose sslserver -verify_hostname portal.opsmatrix.test` → `/etc/ssl/certs/servidor.crt: OK`.

## 5. Nginx

[`layer2-perimeter/nginx/default.conf`](../../layer2-perimeter/nginx/default.conf)

| Requisito | Directiva |
|---|---|
| 80 → HTTPS | `return 301 https://$host$request_uri;` (conserva ruta y parámetros) |
| 443 con TLS | `listen 443 ssl;` |
| Nombre = SAN | `server_name portal.opsmatrix.test;` |
| Rutas internas del contenedor | `ssl_certificate /etc/nginx/certs/servidor.crt;` · `ssl_certificate_key /etc/nginx/certs/servidor.key;` |
| Solo TLS 1.2 y 1.3 | `ssl_protocols TLSv1.2 TLSv1.3;` |
| Backend por DNS de Docker | `proxy_pass http://app:5000;` |
| Host / IP cliente / XFF / protocolo | `proxy_set_header Host $host;` · `X-Real-IP $remote_addr` · `X-Forwarded-For $proxy_add_x_forwarded_for` · `X-Forwarded-Proto $scheme` |

```
$ docker compose exec reverse-proxy nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## 6. Pruebas desde el cliente (Mac)

**Nombre DNS:** sin tocar `/etc/hosts`, con `curl --resolve portal.opsmatrix.test:443:172.16.181.132`. Para el navegador bastaría una línea en `/etc/hosts`: `172.16.181.132 portal.opsmatrix.test`. Por IP directa fallaría (`hostname mismatch`) porque el SAN solo lleva el DNS.

```bash
IP=172.16.181.132; D=portal.opsmatrix.test
curl -sI -H "Host: $D" http://$IP/algo
curl -s --cacert ca.crt --resolve $D:443:$IP https://$D/
curl -s --resolve $D:443:$IP https://$D/            # sin la CA
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -verify_hostname $D -verify_return_error -brief </dev/null
```

```
HTTP/1.1 301 Moved Permanently
Server: nginx
Location: https://portal.opsmatrix.test/algo

<h1>Portal OpsMatrix</h1><p>Visitas guardadas en MariaDB: 1</p><p>Has llegado por: https</p>
<h1>Portal OpsMatrix</h1><p>Visitas guardadas en MariaDB: 2</p><p>Has llegado por: https</p>
404                                   ← /no-existe
exit 60                               ← sin ca.crt

Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: CN=portal.opsmatrix.test
Signature type: rsa_pss_rsae_sha256
Verification: OK
Verified peername: portal.opsmatrix.test
Negotiated TLS1.3 group: X25519MLKEM768
```

| Resultado | Qué demuestra |
|---|---|
| `301` + `Location: https://…/algo` | La redirección conserva la ruta. `Server: nginx` sin versión |
| `Has llegado por: https` | `X-Forwarded-Proto` llega a la app: sabe que el cliente usó HTTPS aunque internamente vaya por HTTP |
| `exit 60` sin `--cacert` | La confianza es real: sin la CA del laboratorio el cliente rechaza el certificado. No se usa `-k` |
| `Verification: OK` + `Verified peername` | Cadena correcta **y** nombre correcto |
| `X25519MLKEM768` | Intercambio de claves híbrido clásico + post-cuántico (ML-KEM, FIPS 203). Lo negocian solos OpenSSL 3.5 en ambos lados. Protege contra "harvest now, decrypt later" |

## 7. Aplicación y persistencia

Reinicio completo del stack (`down` + `up`, sin `-v`) y consulta directa a MariaDB:

```
$ docker compose exec db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT * FROM visitas"'
| id | fecha               | ip           |
|  1 | 2026-10-19 11:14:06 | 172.16.181.1 |
|  2 | 2026-10-19 11:14:06 | 172.16.181.1 |
```

La siguiente visita desde el Mac devuelve `Visitas guardadas en MariaDB: 4`: sigue sumando sobre las anteriores, no vuelve a 1. Entre la consulta y la prueba hubo una petición más.

| Comprobación | Resultado |
|---|---|
| Sin `502 Bad Gateway` | Nginx resuelve `app` por el DNS de Docker |
| App → BBDD | Cada visita es un `INSERT` real |
| Persistencia | Las filas sobreviven a `docker compose down` / `up` gracias al volumen `mariadb_data` |
| IP del cliente | `172.16.181.1` (el Mac), no la IP interna de Nginx: `X-Real-IP` funciona |

## 8. Incidencias reales

| Incidencia | Qué investigué | Solución |
|---|---|---|
| `opsmatrix-db` en bucle de reinicio | `docker logs` → `password option is not specified`. No existía `.env`, y además el compose pedía `DB_*` mientras `.env.example` usaba `MYSQL_*` | Plantilla `.env.example` con los mismos nombres que el compose y `.env` generado en la VM |
| `pip install` sin red durante el build: `Temporary failure in name resolution` | Host resuelve ✅. Contenedor con `--network host` ✅. Red Docker normal ❌, también por IP (`No route to host`). `MASQUERADE` ✅. `FORWARD` con 0 paquetes. Suricata en `copy-mode: none` (no bloquea). **`docker0` sin IP y sin ruta 172.17.0.0/16** | `sudo systemctl restart docker` recrea los bridges con IP. netplan solo gestiona `enp2s0` y networkd los marca `unmanaged`: fallo puntual, no se repite tras 30 s |
| `opsmatrix-app` reiniciándose: `can't open file '/app/app.py': Permission denied` | `ls -l` en la VM → archivos del repo en `600`. La sesión tiene `umask 077` y git los creó así. La app corre como `nobody` | `RUN chmod 644 app.py requirements.txt` en el Dockerfile. Mantengo `USER nobody` en lugar de volver a root |
| Nginx: `host not found in upstream "app"` | Aparecía mientras la app estaba caída: un contenedor que no arranca no tiene nombre en el DNS de Docker | Se resolvió solo al arreglar la app |
| `Server: nginx/1.28.3` en la respuesta del 80 | `server_tokens off` solo estaba en el bloque 443 | Añadido también en el 80 |

**Pendiente para la Fase 5:** `/etc/iptables/rules.v4` (restaurado por `netfilter-persistent`) contiene reglas de Docker antiguas (bridge `br-e2efeb52c253`, subredes 10.0.x) y quedan 4 redes `docker_*` sin contenedores. No afectan al despliegue, pero el firewall real tiene que coincidir con el documentado.

**Contraseñas en el historial de git:** el compose borrado de `layer3` tenía contraseñas de laboratorio escritas. Siguen en commits antiguos. No se usan: la BBDD se inicializó por primera vez con contraseñas nuevas de `openssl rand`, así que las antiguas no abren nada. Añadir `.gitignore` después no las quita del historial; por eso la medida es que dejen de servir, no esconderlas.

## 9. Despliegue reproducible

Requisitos: Docker con Compose v2 y los certificados de la [Fase 2](fase2-pki.md) instalados en `/etc/ssl/`.

```bash
# VM
git clone https://github.com/margalefxr/opsmatrix-lab.git && cd opsmatrix-lab
cp .env.example .env
sed -i "s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(openssl rand -base64 24)|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -base64 24)|" .env
chmod 600 .env
docker compose config --quiet && echo "compose OK"
docker compose up -d --build
docker compose ps
docker compose exec reverse-proxy nginx -t
sudo ss -tulnp | grep -E ':(80|443|3306|5000)\b'      # solo 80 y 443
```

```bash
# Cliente con ca.crt
D=portal.opsmatrix.test; IP=<IP_VM>
curl -sI -H "Host: $D" http://$IP/                                  # 301
curl -s --cacert ca.crt --resolve $D:443:$IP https://$D/            # página + contador
openssl s_client -connect $IP:443 -servername $D -CAfile ca.crt -verify_hostname $D -verify_return_error -brief </dev/null
```

Si el build falla con `Temporary failure in name resolution`: `ip -4 addr show docker0`. Si no tiene IP, `sudo systemctl restart docker`.

Para parar: `docker compose down`. **Nunca `down -v`**: borra el volumen de la BBDD.

## Normativa

| Referencia | Relación |
|---|---|
| ENS (RD 311/2022) mp.com.2 / mp.com.3 | Confidencialidad e integridad en tránsito: TLS 1.2/1.3 en el tramo externo |
| ENS mp.com.1 / ISO 27001 A.8.22 | Segregación de redes: `frontend_net` / `backend_net` (`internal`), solo 80/443 publicados |
| ISO 27001 A.8.24 | Uso de criptografía y custodia de claves: `servidor.key` montada `:ro`, `ca.key` fuera de la VM |
| ISO 27001 A.8.9 / ENS op.exp.3 | Gestión de la configuración: compose e imágenes con versión fijada, todo en git |
| ISO 27001 A.5.17 | Información de autenticación: contraseñas fuera del código, en `.env` con `600` |
| RGPD art. 32 | Cifrado en tránsito para un portal con datos de clientes (gestoría) |
| CCN-STIC-807 / NIST SP 800-52r2 | Configuración TLS admitida: solo 1.2 y 1.3 |
