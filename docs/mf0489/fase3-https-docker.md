# Fase 3 — HTTPS con Nginx y Docker

Publico el portal de OpsMatrix en `https://portal.opsmatrix.test` con el certificado de la Fase 2. Nginx recibe las peticiones, quita el TLS y se las pasa a una app pequeña en Python que guarda cada visita en MariaDB. Las salidas son reales (19/10/2026).

## Resumen

| Criterio | Pts | Evidencia |
|---|---|---|
| F3.1 Compose: proxy funcional, config y certificados montados en solo lectura, config válida | 0,70 | [§2](#2-antes-y-después) · [§5](#5-nginx) |
| F3.2 Nginx en 443, presenta el certificado esperado, `nginx -t` OK | 0,85 | [§5](#5-nginx) · [§6](#6-pruebas-desde-el-mac) |
| F3.3 Solo publica lo necesario, BBDD no expuesta, backend accesible desde la app | 0,60 | [§2](#2-antes-y-después) · [§7](#7-app-y-persistencia) |
| F3.4 App funcionando detrás del proxy, sin 502 y sin perder datos | 0,85 | [§7](#7-app-y-persistencia) |
| F3.5 HTTPS verificado desde el cliente con `curl --cacert`, sin `-k` | 0,65 | [§6](#6-pruebas-desde-el-mac) |
| F3.6 HTTP → HTTPS conservando host y ruta | 0,35 | [§6](#6-pruebas-desde-el-mac) |

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

El diagrama completo está en la [Fase 1](fase1-arquitectura.md#diagrama) y el final en la [Fase 5](fase5-entrega-final.md#1-arquitectura-final).

**Decisiones obligatorias (Actividad 9):**

| # | Decisión | Respuesta |
|---|---|---|
| 1 | Contenedor que hace de reverse proxy | Uno **nuevo**, `reverse-proxy` (`nginx:1.28-alpine`). El Nginx anterior no tenía nada que aprovechar |
| 2 | Nombre, puerto y protocolo de la app | `app`, puerto **5000**, **HTTP**. No se publica en la VM |
| 3 | Quién comparte la red web | `reverse-proxy` y `app` en `frontend_net`. Nginx llega a la app por su nombre DNS `app` |
| 4 | Quién comparte la red de BBDD | `app` y `db` en `backend_net` (`internal: true`). Nginx no está |
| 5 | Dónde termina TLS | En Nginx. Nginx → app va por HTTP interno, y está documentado como límite |

## 2. Antes y después

**Antes** (Actividad 8, 19/10 10:33 UTC). Notas completas: [`actividad8.txt`](evidencias/fase3/actividad8.txt).

```
$ docker compose ls
opsmatrix-lab   restarting(1), running(1)   /home/server/opsmatrix-lab/docker-compose.yml
$ docker compose ps
opsmatrix-web   nginx:alpine    Up 3 weeks       0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
opsmatrix-db    mariadb:10.11   Restarting (1)
$ sudo ss -tulnp      # 22 sshd, 80 y 443 docker-proxy. 3306 no publicado
$ curl -v http://localhost/
curl: (56) Recv failure: Connection reset by peer
```

| Pregunta de la Actividad 8 | Respuesta |
|---|---|
| ¿Qué contenedor sirve la app? | Ninguno de verdad: `opsmatrix-web` solo tenía la página por defecto de Nginx |
| ¿Cuál tiene la BBDD? | `opsmatrix-db`, con el volumen `opsmatrix-lab_mariadb_data` |
| ¿Hay reverse proxy? | No |
| ¿Qué compose se usa? | El de la raíz. El de `layer3-services/docker/` no se usaba |


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
$ sudo ss -tulnp | grep -E ':(22|80|443|3306|5000)\b'      # recortado, completo en check-vm.txt §8
0.0.0.0:80    docker-proxy
0.0.0.0:22    sshd
0.0.0.0:443   docker-proxy
```

```
$ docker compose config --quiet && echo "compose OK"
compose OK
$ docker compose ps                     # columnas recortadas (persistencia.txt)
NAME              IMAGE               SERVICE         STATUS          PORTS
opsmatrix-app     opsmatrix-lab-app   app             Up 15 seconds   5000/tcp
opsmatrix-db      mariadb:10.11       db              Up 15 seconds   3306/tcp
opsmatrix-proxy   nginx:1.28-alpine   reverse-proxy   Up 15 seconds   0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp
# montajes del proxy (comprobado el 20/10 en la Fase 4)
$ docker inspect opsmatrix-proxy -f '{{range .Mounts}}{{.Destination}} rw={{.RW}}{{"\n"}}{{end}}'
/etc/nginx/conf.d/default.conf rw=false
/etc/nginx/certs/servidor.crt rw=false
/etc/nginx/certs/servidor.key rw=false
```

Solo el proxy publica puertos (80 y 443). La app y la BBDD salen con su puerto interno (`5000/tcp`, `3306/tcp`), sin `0.0.0.0`. Los tres montajes del proxy son de solo lectura (`rw=false`).

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
| Imágenes por rama (`nginx:1.28-alpine`, `mariadb:10.11`) | Que no entre una versión mayor nueva sin querer, como pasaría con `latest`. Los parches sí entran. Fijarlas por digest (`@sha256:…`) sería lo exacto, pero habría que actualizarlas a mano |
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
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
$ docker compose logs --tail=5 app reverse-proxy      # recortado
opsmatrix-proxy  | 172.16.181.1 - - [19/Oct/2026:11:18:29 +0000] "HEAD /algo HTTP/1.1" 301 0 "-" "curl/8.7.1" "-"
opsmatrix-proxy  | 172.16.181.1 - - [19/Oct/2026:11:18:29 +0000] "GET / HTTP/1.1" 200 92 "-" "curl/8.7.1" "-"
opsmatrix-app  | 172.23.0.3 - - [19/Oct/2026 11:18:29] "GET / HTTP/1.0" 200 -
```

La app ve las peticiones desde `172.23.0.3`, que es Nginx dentro de `frontend_net`, no desde el Mac. Por eso la IP real del cliente le llega en `X-Real-IP`. Salida completa en [`check-vm.txt`](evidencias/fase3/check-vm.txt) §7 y §12.

## 6. Pruebas desde el Mac

**¿Cómo resuelvo el nombre?** Con `curl --resolve portal.opsmatrix.test:443:172.16.181.132`, sin tocar `/etc/hosts`. Para el navegador habría que añadir `172.16.181.132 portal.opsmatrix.test` en `/etc/hosts`. Entrar por IP no vale porque el certificado solo tiene el nombre DNS.

Todas las pruebas están en [`scripts/check-mac.sh`](../../scripts/check-mac.sh). Salida completa en [`evidencias/fase3/check-mac.txt`](evidencias/fase3/check-mac.txt).

```
$ curl -sI --resolve portal.opsmatrix.test:80:172.16.181.132 http://portal.opsmatrix.test/prueba
HTTP/1.1 301 Moved Permanently
Server: nginx
Location: https://portal.opsmatrix.test/prueba

$ curl -s -w "\ncodigo=%{http_code} tls=%{ssl_verify_result}\n" --cacert ca.crt \
    --resolve portal.opsmatrix.test:443:172.16.181.132 https://portal.opsmatrix.test/
<h1>Portal OpsMatrix</h1><p>Visitas guardadas en MariaDB: 5</p><p>Has llegado por: https</p>
codigo=200 tls=0
```

`tls=0` es el resultado de la verificación del certificado: 0 significa correcto (cadena y nombre).

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

`Verification: OK` quiere decir que la firma es de mi CA, y `Verified peername` que el nombre coincide. La huella del certificado que entrega Nginx es la del `servidor.crt` firmado (`13:2B:31:0E…06:EE`, [`check-mac-final2.txt`](evidencias/fase5/check-mac-final2.txt) §7). El grupo `X25519MLKEM768` es un intercambio de claves que mezcla uno clásico con uno post-cuántico (ML-KEM). No lo configuré yo: lo eligen solos OpenSSL 3.5 del Mac y de la VM.

## 7. App y persistencia

La app guarda en la tabla `visitas` la fecha y la IP de cada visita y enseña el total.

**¿Se conservan los datos al reiniciar?** Sí. Hice `docker compose down` y `up` (sin `-v`) y consulté la tabla ([`persistencia.txt`](evidencias/fase3/persistencia.txt)):

```
| id | fecha               | ip           |
|  1 | 2026-10-19 11:14:06 | 172.16.181.1 |
|  2 | 2026-10-19 11:14:06 | 172.16.181.1 |
```

Después de reiniciar, la siguiente visita sumó sobre las anteriores en vez de volver a 1. En el log de Nginx se ven dos `GET /` justo después del reinicio (11:18:26 y 11:18:29), por eso el contador marcó 4.

| Comprobación | Resultado |
|---|---|
| Navegación | La app tiene una sola página (`/`): `200`. Cualquier otra ruta da `404`, sin `502` (rutas `/mf0489-…` en la [Fase 4](fase4-auditoria-tls-monitorizacion.md#6-log-de-nginx)) |
| Sin `502 Bad Gateway` | Nginx encuentra la app por su nombre `app` |
| La app escribe en MariaDB | Cada visita es una fila nueva |
| Los datos sobreviven a `down` / `up` | Se guardan en el volumen `mariadb_data`. La primera visita (19/10 11:14:06) sigue ahí el 21/10, después de reiniciar la VM ([`check-vm-github.txt`](evidencias/fase5/check-vm-github.txt) §11) |
| La IP guardada es la del Mac (`172.16.181.1`) | La cabecera `X-Real-IP` llega bien |

**Aislamiento** (con [`scripts/check-vm.sh`](../../scripts/check-vm.sh), salida en [`evidencias/fase3/check-vm.txt`](evidencias/fase3/check-vm.txt)):

| Prueba | Control (demuestra que la prueba funciona) | Resultado |
|---|---|---|
| Nginx → app | — | Responde |
| Nginx → BBDD | `getent hosts app` sí resuelve (`172.23.0.3`) | Ni siquiera encuentra el nombre `db` |
| BBDD → internet | La app sí sale (`rc=0`) y la BBDD tiene `bash` y `timeout` | No sale (`rc=1`). Su tabla de rutas no tiene ruta por defecto, solo `backend_net` |
| Usuario de la app | — | `uid=65534(nobody)` |

Sin el control, un "OK" también saldría si fallara el comando. Salida: [`check-vm-controles.txt`](evidencias/fase5/check-vm-controles.txt) §10.

## 8. Dificultades

| Problema | Qué miré | Causa | Solución |
|---|---|---|---|
| La BBDD se reiniciaba cada minuto | `docker logs opsmatrix-db` | No había `.env` y además los nombres de las variables no coincidían (`DB_*` en el compose, `MYSQL_*` en el ejemplo) | `.env.example` con los mismos nombres y `.env` creado en la VM con `openssl rand` ([`env-creado.txt`](evidencias/fase3/env-creado.txt)) |
| `pip install` fallaba al construir la app (`Temporary failure in name resolution`) | La VM sí tenía internet. Un contenedor con `--network host` también. Uno normal no, ni por IP. La regla de NAT estaba, el firewall no lo tiraba y Suricata solo escucha | `docker0` (la red por defecto de Docker) no tenía IP, así que los contenedores no tenían por dónde salir | `sudo systemctl restart docker`. A los 30 segundos seguía bien |
| La app se reiniciaba: `Permission denied` en `app.py` | `ls -l` en la VM: los archivos del repo salían con 600 | Tengo `umask 077` en la VM. La app corre como `nobody` y no podía leer el archivo | `RUN chmod 644` en el Dockerfile. No cambio el usuario a root |
| Nginx: `host not found in upstream "app"` | Salía mientras la app estaba caída | Si la app no arranca, Docker no le da nombre | Se arregló solo al arreglar la app |
| El puerto 80 enseñaba `Server: nginx/1.28.3` | `curl -I` | `server_tokens off` solo estaba en el bloque del 443 | Lo puse también en el 80 |
| Había un `ca.key` en la VM | La revisión final avisó. Comparé el hash del archivo con el de la CA del Mac y eran distintos | Era la CA antigua del MF0488, en `layer2-perimeter/pki/`, junto con un `server.key` viejo en `nginx/ssl/`. Nunca llegaron a git | Borrados con `shred -u`. Ahora `find` no encuentra ningún `ca.key` y la única clave es `/etc/ssl/private/servidor.key` |

Salidas reales de estas incidencias: [`incidencias.txt`](evidencias/fase3/incidencias.txt) y [`actividad8.txt`](evidencias/fase3/actividad8.txt) (BBDD sin `.env`). El `ca.key` viejo sale como `ALERTA` en [`check-vm.txt`](evidencias/fase3/check-vm.txt) §5 y ya no en [`check-vm-final.txt`](evidencias/fase5/check-vm-final.txt).

**Contraseñas en el historial de git:** el compose que borré tenía contraseñas de laboratorio y siguen en commits antiguos. No dan acceso a la BBDD actual: se creó por primera vez con las nuevas del `.env`. Poner algo en `.gitignore` después no lo quita del historial.

**Para la Fase 5:** SSH sigue aceptando contraseña, `/etc/iptables/rules.v4` carga 22 reglas de bridges de Docker que ya no existen y quedan 4 redes `docker_*` vacías. Resuelto en la [Fase 5](fase5-entrega-final.md#2-qué-corre-de-verdad).

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
| ENS mp.com.1 y mp.com.4 / ISO 27001 A.8.22 | Separar redes: `frontend_net` y `backend_net`, solo 80 y 443 abiertos |
| ISO 27001 A.8.24 | Uso de criptografía y cuidado de las claves |
| ISO 27001 A.5.17 | Contraseñas fuera del código, en `.env` |
| RGPD art. 32 | Cifrado en tránsito para un portal con datos de clientes |
| CCN-STIC-807 / NIST SP 800-52r2 | Solo TLS 1.2 y 1.3 |
