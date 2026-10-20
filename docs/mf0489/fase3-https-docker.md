# Fase 3 — HTTPS con Nginx y Docker

Publico el portal de OpsMatrix en `https://portal.opsmatrix.test` con el certificado de la Fase 2. Nginx recibe las peticiones, quita el TLS y se las pasa a una app pequeña en Python que guarda cada visita en MariaDB. Las salidas son reales (19/10/2026).

## Resumen

| Lo que pide la fase | Resultado | Dónde |
|---|---|---|
| Entrar por `https://portal.opsmatrix.test` (443) | ✅ | [§6](#6-pruebas-desde-el-mac) |
| Nginx usa el certificado y la clave de la Fase 2 | ✅ | [§4](#4-certificados) |
| El certificado se verifica con la CA, sin `-k` | ✅ | [§6](#6-pruebas-desde-el-mac) |
| HTTP redirige a HTTPS | ✅ | [§6](#6-pruebas-desde-el-mac) |
| Nginx → app → BBDD funciona y los datos se guardan | ✅ | [§7](#7-app-y-persistencia) |
| App y BBDD sin puertos abiertos al exterior | ✅ | [§2](#2-antes-y-después) |
| Nada secreto en GitHub | ✅ | [§3](#3-decisiones) |

## 1. Arquitectura

```
Mac (cliente) ──HTTPS 443──▶ Nginx ──HTTP 5000──▶ app (Flask) ──3306──▶ MariaDB
              ──HTTP  80 ──▶ (301)   frontend_net               backend_net (internal)
```

**¿Dónde termina TLS?** En Nginx. Del Mac a Nginx va cifrado. De Nginx a la app y de la app a la BBDD va sin cifrar, pero esos tramos no salen de la VM.

| Tramo | Cifrado | Motivo |
|---|---|---|
| Mac → Nginx | ✅ TLS 1.2 / 1.3 | Es el único que pasa por la red |
| Nginx → app | ❌ | Red interna de Docker |
| app → MariaDB | ❌ | `backend_net` es `internal`: no tiene salida ni entrada desde fuera |

El diagrama completo está en la [Fase 1](fase1-arquitectura.md#diagrama).

## 2. Antes y después

**Antes** (lo que encontré al revisar la VM):

| Contenedor | Estado | Problema |
|---|---|---|
| `opsmatrix-web` (`nginx:alpine`) | Encendido, 80 y 443 abiertos | Tenía la config por defecto de la imagen. `curl http://localhost/` → `Connection reset by peer` |
| `opsmatrix-db` (MariaDB) | Reiniciándose cada minuto | `Database is uninitialized and password option is not specified`. No había `.env` |
| Compose de `layer3-services/docker/` | Sin usar | Tenía las contraseñas escritas dentro |

**Después:**

| Servicio | Imagen | Redes | Puerto | ¿Abierto en la VM? |
|---|---|---|---|---|
| `reverse-proxy` | `nginx:1.28-alpine` | `frontend_net` | 80, 443 | ✅ |
| `app` | Flask (la construyo con el Dockerfile) | `frontend_net` + `backend_net` | 5000 | ❌ solo `expose` |
| `db` | `mariadb:10.11` | `backend_net` | 3306 | ❌ |

```
$ sudo ss -tulnp | grep -E ':(22|80|443|3306|5000)\b'
0.0.0.0:80   docker-proxy
0.0.0.0:22   sshd
0.0.0.0:443  docker-proxy
```

**Copia de seguridad antes de tocar nada** (con `down`, nunca `down -v`):

```
docker compose down
sudo tar czf ~/backups/mariadb_data-2026-10-19.tgz -C /var/lib/docker/volumes/opsmatrix-lab_mariadb_data _data
-rw------- 1 root root 131 Oct 19 10:51 mariadb_data-2026-10-19.tgz
```

Pesa 131 bytes porque el volumen estaba vacío: la BBDD nunca llegó a arrancar, así que no había datos que perder. La config anterior está en git (commit `604c5b2`) por si hay que volver atrás.

## 3. Decisiones

| Decisión | Motivo |
|---|---|
| Nginx nuevo como reverse proxy | El que había solo servía la página por defecto, no había nada que aprovechar |
| App nueva en Flask | No había app. Necesitaba algo que escriba en MariaDB para comprobar que todo funciona detrás del proxy |
| Nginx solo en `frontend_net` | No necesita hablar con la BBDD. Si alguien entra en Nginx, no llega directo a MariaDB |
| La app en las dos redes | Es la única que tiene que hablar con la BBDD |
| `expose` en la app en vez de `ports` | Así solo se ve dentro de Docker. La única entrada es Nginx |
| Contraseñas en `.env` (600, en `.gitignore`) | En el MF0488 me penalizaron por tenerlas escritas en el compose |
| La app corre como `nobody` | Si la explotan, no es root dentro del contenedor |
| Versiones fijas (`nginx:1.28-alpine`, `mariadb:10.11`) | Para que siempre se instale lo mismo y no lo que traiga `latest` ese día |
| Un solo `docker-compose.yml` | Había dos y uno no se usaba. Borré el que sobraba |
| La app usa el servidor de pruebas de Flask | Basta para un laboratorio con una visita cada vez. En producción iría detrás de un servidor WSGI como gunicorn (Flask avisa de ello en el log) |

### Preguntas de la Actividad 10

| Pregunta | Respuesta |
|---|---|
| ¿Qué hace `ports`? | Abre un puerto de la VM y lo conecta con el del contenedor (`"443:443"` = VM:contenedor). Sin `ports`, el servicio solo se ve dentro de Docker |
| ¿Para qué sirve cada `volume`? | `default.conf` es la config de Nginx. `servidor.crt` es el certificado que enseña. `servidor.key` es su clave privada. `mariadb_data` guarda la BBDD fuera del contenedor para no perderla |
| ¿Qué significa `:ro`? | Solo lectura. Nginx puede leer los archivos pero no cambiarlos |
| ¿Por qué Nginx necesita `servidor.key` y no `ca.key`? | Con `servidor.key` demuestra que es el dueño del certificado en cada conexión. `ca.key` solo sirve para firmar certificados nuevos y eso ya se hizo en el Mac. El cliente comprueba con `ca.crt`, que es público |
| ¿El proxy necesita estar en la red de la BBDD? | No. Solo habla con la app |

## 4. Certificados

| En la VM | Permisos | Dentro del contenedor |
|---|---|---|
| `/etc/ssl/private/servidor.key` | 600 root | `/etc/nginx/certs/servidor.key` (`:ro`) |
| `/etc/ssl/certs/servidor.crt` | 644 root | `/etc/nginx/certs/servidor.crt` (`:ro`) |
| `/etc/ssl/mf0489/ca.crt` | 644 root | No se monta, Nginx no la necesita |
| `ca.key` | — | Solo en el Mac |

Nginx puede leer la clave aunque sea 600 porque arranca como root. La clave se monta al arrancar, no se copia dentro de ninguna imagen.

Comprobación previa: `openssl verify -CAfile /etc/ssl/mf0489/ca.crt -purpose sslserver -verify_hostname portal.opsmatrix.test /etc/ssl/certs/servidor.crt` → `OK`.

## 5. Nginx

Archivo: [`layer2-perimeter/nginx/default.conf`](../../layer2-perimeter/nginx/default.conf)

| Requisito | Cómo lo hago |
|---|---|
| 80 redirige a HTTPS | `return 301 https://$host$request_uri;` |
| 443 con TLS | `listen 443 ssl;` |
| Mismo nombre que el SAN | `server_name portal.opsmatrix.test;` |
| Rutas de dentro del contenedor | `ssl_certificate /etc/nginx/certs/servidor.crt;` y `ssl_certificate_key /etc/nginx/certs/servidor.key;` |
| Solo TLS 1.2 y 1.3 | `ssl_protocols TLSv1.2 TLSv1.3;` |
| Pasar a la app por su nombre en Docker | `proxy_pass http://app:5000;` |
| Host, IP del cliente y protocolo | `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` |
| No enseñar la versión | `server_tokens off;` en los dos bloques |

```
$ docker compose exec reverse-proxy nginx -t
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## 6. Pruebas desde el Mac

**¿Cómo resuelvo el nombre?** Con `curl --resolve portal.opsmatrix.test:443:172.16.181.132`, sin tocar `/etc/hosts`. Para el navegador habría que añadir `172.16.181.132 portal.opsmatrix.test` en `/etc/hosts`. Entrar por IP no vale porque el certificado solo tiene el nombre DNS.

Todas las pruebas están en [`scripts/check-mac.sh`](../../scripts/check-mac.sh). Salida completa en [`evidencias/check-mac.txt`](evidencias/check-mac.txt).

| Prueba | Resultado | ✔ |
|---|---|---|
| `curl -I` por HTTP | `301`, `Location: https://portal.opsmatrix.test/prueba`, `Server: nginx` (sin versión) | ✅ |
| `curl --cacert ca.crt` por HTTPS | `200`, la página dice `Has llegado por: https` | ✅ |
| Sin `--cacert` | `exit 60` (no confía en el certificado) | ✅ |
| Con otro nombre (`otro.opsmatrix.test`) | `exit 60` (el nombre no coincide) | ✅ |
| Puertos 3306 y 5000 desde el Mac | Cerrados | ✅ |

```
$ openssl s_client -connect 172.16.181.132:443 -servername portal.opsmatrix.test \
    -CAfile ca.crt -verify_hostname portal.opsmatrix.test -verify_return_error -brief
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: CN=portal.opsmatrix.test
Verification: OK
Verified peername: portal.opsmatrix.test
Negotiated TLS1.3 group: X25519MLKEM768
```

`Verification: OK` quiere decir que la firma es de mi CA, y `Verified peername` que el nombre coincide. El grupo `X25519MLKEM768` es un intercambio de claves que mezcla uno clásico con uno post-cuántico (ML-KEM). No lo configuré yo: lo eligen solos OpenSSL 3.5 del Mac y de la VM.

## 7. App y persistencia

La app guarda en la tabla `visitas` la fecha y la IP de cada visita y enseña el total.

**¿Se conservan los datos al reiniciar?** Sí. Hice `docker compose down` y `up` (sin `-v`) y consulté la tabla:

```
| id | fecha               | ip           |
|  1 | 2026-10-19 11:14:06 | 172.16.181.1 |
|  2 | 2026-10-19 11:14:06 | 172.16.181.1 |
```

Después de reiniciar, la siguiente visita sumó sobre las anteriores en vez de volver a 1. En el log de Nginx se ven dos `GET /` justo después del reinicio (11:18:26 y 11:18:29), por eso el contador marcó 4.

| Comprobación | Resultado |
|---|---|
| Sin `502 Bad Gateway` | Nginx encuentra la app por su nombre `app` |
| La app escribe en MariaDB | Cada visita es una fila nueva |
| Los datos sobreviven a `down` / `up` | Se guardan en el volumen `mariadb_data` |
| La IP guardada es la del Mac (`172.16.181.1`) | La cabecera `X-Real-IP` llega bien |

**Aislamiento** (con [`scripts/check-vm.sh`](../../scripts/check-vm.sh), salida en [`evidencias/check-vm.txt`](evidencias/check-vm.txt)):

| Prueba | Resultado |
|---|---|
| Nginx → app | Responde |
| Nginx → BBDD | Ni siquiera encuentra el nombre `db` |
| BBDD → internet | No puede salir |
| Usuario de la app | `uid=65534(nobody)` |

## 8. Dificultades

| Problema | Qué miré | Causa | Solución |
|---|---|---|---|
| La BBDD se reiniciaba cada minuto | `docker logs opsmatrix-db` | No había `.env` y además los nombres de las variables no coincidían (`DB_*` en el compose, `MYSQL_*` en el ejemplo) | `.env.example` con los mismos nombres y `.env` creado en la VM con `openssl rand` |
| `pip install` fallaba al construir la app (`Temporary failure in name resolution`) | La VM sí tenía internet. Un contenedor con `--network host` también. Uno normal no, ni por IP. La regla de NAT estaba, el firewall no lo tiraba y Suricata solo escucha | `docker0` (la red por defecto de Docker) no tenía IP, así que los contenedores no tenían por dónde salir | `sudo systemctl restart docker`. A los 30 segundos seguía bien |
| La app se reiniciaba: `Permission denied` en `app.py` | `ls -l` en la VM: los archivos del repo salían con 600 | Tengo `umask 077` en la VM. La app corre como `nobody` y no podía leer el archivo | `RUN chmod 644` en el Dockerfile. No cambio el usuario a root |
| Nginx: `host not found in upstream "app"` | Salía mientras la app estaba caída | Si la app no arranca, Docker no le da nombre | Se arregló solo al arreglar la app |
| El puerto 80 enseñaba `Server: nginx/1.28.3` | `curl -I` | `server_tokens off` solo estaba en el bloque del 443 | Lo puse también en el 80 |
| Había un `ca.key` en la VM | La revisión final avisó. Comparé el hash del archivo con el de la CA del Mac y eran distintos | Era la CA antigua del MF0488, en `layer2-perimeter/pki/`, junto con un `server.key` viejo en `nginx/ssl/`. Nunca llegaron a git | Borrados con `shred -u`. Ahora `find` no encuentra ningún `ca.key` y la única clave es `/etc/ssl/private/servidor.key` |

**Contraseñas en el historial de git:** el compose que borré tenía contraseñas de laboratorio y siguen en commits antiguos. No sirven para nada: la BBDD se creó por primera vez con las nuevas del `.env`. Poner algo en `.gitignore` después no lo quita del historial.

**Para la Fase 5:** SSH sigue aceptando contraseña, `/etc/iptables/rules.v4` tiene 22 reglas viejas del MF0488 y quedan 4 redes `docker_*` vacías. Resuelto en la [Fase 5](fase5-entrega-final.md#2-qué-corre-de-verdad).

## 9. Cómo desplegarlo

Con los certificados de la [Fase 2](fase2-pki.md) en `/etc/ssl/`:

```bash
bash scripts/deploy.sh     # crea el .env con contraseñas aleatorias y levanta el compose
bash scripts/check-vm.sh   # comprobar
```

Paso a paso, copias y problemas conocidos en la [guía de despliegue](guia-despliegue.md). Para parar: `docker compose down`, **nunca `down -v`** (borra la BBDD).

## Normativa

| Referencia | Relación |
|---|---|
| ENS (RD 311/2022) mp.com.2 y mp.com.3 | Cifrado de las comunicaciones: TLS en el tramo externo |
| ENS mp.com.1 / ISO 27001 A.8.22 | Separar redes: `frontend_net` y `backend_net`, solo 80 y 443 abiertos |
| ISO 27001 A.8.24 | Uso de criptografía y cuidado de las claves |
| ISO 27001 A.5.17 | Contraseñas fuera del código, en `.env` |
| RGPD art. 32 | Cifrado en tránsito para un portal con datos de clientes |
| CCN-STIC-807 / NIST SP 800-52r2 | Solo TLS 1.2 y 1.3 |
