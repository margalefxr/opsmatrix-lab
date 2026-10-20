# Fase 4 — Auditoría TLS y monitorización

Compruebo que el HTTPS montado en la Fase 3 está bien configurado y que, aunque el tráfico vaya cifrado, puedo seguir viendo qué pasa con Suricata y con los logs de Nginx. Las salidas son reales (20/10/2026, horas en UTC).

## Resumen

| Criterio | Pts | Evidencia |
|---|---|---|
| F4.1 Línea base HTTPS: certificado confiable, nombre, versión TLS y cipher suite | 0,45 | [§2](#2-conexión-https-real) |
| F4.2 TLS 1.2/1.3 sí, obsoletos no, contrastado con la config activa | 0,50 | [§3](#3-versiones-tls) |
| F4.3 Comparativa HTTP/HTTPS desde la interfaz: qué ve Suricata y qué solo ve Nginx | 0,45 | [§4](#4-qué-se-ve-en-http-y-en-https) |
| F4.4 Suricata en la interfaz correcta, regla propia, `suricata -T` y alerta real | 0,50 | [§1](#1-máquinas-e-interfaz) · [§5](#5-regla-de-suricata) · [§7](#7-correlación) |
| F4.5 Correlación Suricata ↔ Nginx con IP, hora y diferencias por NAT/Docker | 0,40 | [§7](#7-correlación) |
| F4.6 App, BBDD, TLS y monitorización siguen funcionando | 0,20 | [§9](#9-checklist-final) |

## 1. Máquinas e interfaz

| | Equipo | IP | Papel |
|---|---|---|---|
| Cliente | Mac (está en la misma red que la VM y ya tiene `ca.crt`) | 172.16.181.1 | Lanza las pruebas |
| Servidor | Ubuntu `ubuntuserver` | 172.16.181.132 | Nginx + app + MariaDB en Docker |
| Interfaz | `enp2s0` | — | Por donde entra el cliente. Es la que escucha Suricata (`- interface: enp2s0`) |

Scripts usados: [`scripts/fase4-mac.sh`](../../scripts/fase4-mac.sh) y [`scripts/fase4-vm.sh`](../../scripts/fase4-vm.sh). Salidas en [`evidencias/fase4-mac.txt`](evidencias/fase4-mac.txt), [`evidencias/fase4-vm.txt`](evidencias/fase4-vm.txt) (aún con las alertas duplicadas) y [`evidencias/fase4-correlacion-02.txt`](evidencias/fase4-correlacion-02.txt) (prueba final ya arreglada).

## 2. Conexión HTTPS real

Aquí compruebo el certificado que **entrega Nginx** al conectar, no el archivo `servidor.crt`.

```
$ curl -v --cacert ca.crt --resolve portal.opsmatrix.test:443:172.16.181.132 https://portal.opsmatrix.test/
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
*  subject: CN=portal.opsmatrix.test
*  subjectAltName: host "portal.opsmatrix.test" matched cert's "portal.opsmatrix.test"
*  issuer: C=ES; O=OpsMatrix Lab; CN=OpsMatrix Lab Root CA
*  SSL certificate verify ok.
< HTTP/1.1 200 OK
```

| Prueba | Resultado real | Evidencia |
|---|---|---|
| Contenedores y proxy activos | 3 `Up`, `nginx -t` OK | `fase4-vm.txt` §10 |
| 443 accesible desde el cliente | Sí | `curl` conecta |
| Certificado y dominio válidos | `CN=portal.opsmatrix.test`, el SAN coincide | `subjectAltName … matched` |
| Verificación de confianza | `SSL certificate verify ok` / `Verification: OK` | curl y s_client |
| Versión TLS | TLS 1.3 | `SSL connection using TLSv1.3` |
| Cipher suite | `CHACHA20-POLY1305` (curl del Mac) / `AES_256_GCM` (openssl) | §3 |
| Aplicación | `HTTP/1.1 200 OK` | curl |

## 3. Versiones TLS

**Configuración cargada de verdad** (no la del repo, la del contenedor):

```
$ docker compose exec reverse-proxy nginx -T | grep ssl_protocols
    ssl_protocols       TLSv1.2 TLSv1.3;
```

| Protocolo | Resultado real | ¿Cumple? |
|---|---|---|
| TLS 1.3 | `TLS_AES_256_GCM_SHA384`, `Verification: OK`, grupo `X25519MLKEM768` | ✅ |
| TLS 1.2 | `ECDHE-RSA-AES256-GCM-SHA384`, `Verification: OK`, clave temporal X25519 | ✅ |
| TLS 1.1 | El servidor contesta `alert protocol version` (alerta 70) | ✅ rechazado |

**¿Por qué dos pruebas de TLS 1.1?** Con el comando del enunciado sale `no protocols available`. Eso lo dice **mi** OpenSSL 3.5, que ya no deja usar TLS 1.1, así que no demuestra nada del servidor. Repetí bajando el nivel de seguridad del cliente (`-cipher DEFAULT@SECLEVEL=0`). Así el cliente sí manda el saludo en TLS 1.1 y es **Nginx** quien lo rechaza con la alerta 70. Suricata también registró ese intento como `"version":"TLS 1.1"`.

### Preguntas 16.4

| Pregunta | Respuesta |
|---|---|
| ¿Qué versión se negoció? | TLS 1.3 por defecto. TLS 1.2 cuando lo forcé |
| ¿Qué cipher suite? | TLS 1.3: `TLS_AES_256_GCM_SHA384` con openssl y `TLS_CHACHA20_POLY1305_SHA256` con curl del Mac (cada cliente pide su preferida). TLS 1.2: `ECDHE-RSA-AES256-GCM-SHA384` |
| ¿Qué protege? | El intercambio de claves (ECDHE / X25519) crea una clave nueva en cada conexión, así que aunque roben `servidor.key` más adelante no pueden descifrar lo grabado antes (forward secrecy). AES-256-GCM y ChaCha20-Poly1305 cifran y a la vez detectan si alguien cambia algo (AEAD) |
| ¿Cipher suite = algoritmo de firma del certificado? | No. El certificado lo firmó la CA una sola vez con `sha256WithRSAEncryption` y sirve para saber **quién** es el servidor. La cipher suite se negocia en cada conexión y sirve para **cifrar** los datos. En medio, el servidor firma el handshake con su clave (`rsa_pss_rsae_sha256`) para demostrar que el certificado es suyo |
| ¿Qué pasa con TLS 1.1? | No se completa. El cliente moderno ni lo intenta y, si se le obliga, Nginx lo corta con `protocol version` |

## 4. Qué se ve en HTTP y en HTTPS

Capturé `enp2s0` con `tcpdump` mientras el Mac pedía `/mf0489-prueba-http` (puerto 80) y `/mf0489-prueba-https` (puerto 443).

| Desde la interfaz externa | HTTP :80 | HTTPS :443 |
|---|---|---|
| IP origen y destino | ✅ | ✅ |
| Puerto | ✅ | ✅ |
| Método (`HEAD`, `GET`) | ✅ `HEAD` | ❌ |
| Ruta (`/mf0489-prueba-…`) | ✅ `/mf0489-prueba-http` | ❌ 0 apariciones en la captura |
| Versión TLS / metadatos | — | ✅ versión, SNI `portal.opsmatrix.test`, huella JA4 |
| Contenido en texto claro | ✅ cabeceras y `Location` | ❌ |
| Eventos en Suricata | `http` (url, método, estado 301) + alerta 1000002 | `tls` (versión, SNI) + alerta 1000003 |

**HTTPS no lo esconde todo.** Se siguen viendo IPs, puertos, tamaños, horas y el nombre del servidor (SNI), que va en claro en el saludo. El certificado no se ve porque en TLS 1.3 viaja cifrado.

```
# tcpdump -i enp2s0 -A 'tcp port 80'  → se lee todo
08:31:08.191339 IP 172.16.181.1.64842 > 172.16.181.132.80: ... HTTP: HEAD /mf0489-prueba-http HTTP/1.1
Host: portal.opsmatrix.test
08:31:08.192249 IP 172.16.181.132.80 > 172.16.181.1.64842: ... HTTP: HTTP/1.1 301 Moved Permanently
Location: https://portal.opsmatrix.test/mf0489-prueba-http

# tcpdump -i enp2s0 -A 'tcp port 443' → 485 líneas, la ruta 0 veces, solo el SNI legible
08:31:08.043740 IP 172.16.181.1.64837 > 172.16.181.132.443: Flags [SEW] ...
.........portal.opsmatrix.test.......
```

Que la ruta no salga en la captura no es por sí sola una prueba de cifrado. Lo que lo demuestra es esa observación junto con la conexión verificada con `curl` y `openssl` (§2 y §3).

## 5. Regla de Suricata

En [`layer1-telemetry/suricata/rules/local.rules`](../../layer1-telemetry/suricata/rules/local.rules), instalada en `/var/lib/suricata/rules/local.rules`. Es el archivo que carga Suricata: en `suricata.yaml` están `default-rule-path: /var/lib/suricata/rules` y `rule-files: - local.rules`.

```
alert tcp any any -> $HOME_NET 443 (msg:"MF0489 - Conexion HTTPS observada"; flow:to_server; flags:S,CE; sid:1000003; rev:2;)
```

| Parte | Por qué |
|---|---|
| `-> $HOME_NET 443` | Solo conexiones al 443 del servidor. `HOME_NET` incluye `172.16.0.0/12`, que contiene `172.16.181.132` |
| `flags:S,CE` | Solo el primer paquete de la conexión (SYN), ignorando los bits ECN |
| `flow:to_server` | Solo cliente → servidor |
| `sid:1000003` | Libre: el 1000001 y el 1000002 son del MF0488 y los mantengo |

```
$ sudo suricata -T -c /etc/suricata/suricata.yaml
Configuration provided was successfully loaded.
3 rules successfully loaded, 0 rules failed
```

Es una regla de laboratorio: un SYN al 443 es una conexión normal, **no un ataque**. En una red con tráfico real haría mucho ruido.

## 6. Log de Nginx

Añadí en [`default.conf`](../../layer2-perimeter/nginx/default.conf) un formato con fecha con zona horaria, IP y puerto del cliente, petición, estado, versión TLS y cipher:

```nginx
log_format mf0489 '$time_iso8601 client=$remote_addr:$remote_port '
                  'request="$request" status=$status '
                  'tls=$ssl_protocol cipher=$ssl_cipher';
```

```
2026-10-20T08:31:08+00:00 client=172.16.181.1:64842 request="HEAD /mf0489-prueba-http HTTP/1.1" status=301 tls=- cipher=-
2026-10-20T08:31:08+00:00 client=172.16.181.1:64843 request="GET /mf0489-prueba-https HTTP/1.1" status=404 tls=TLSv1.3 cipher=TLS_CHACHA20_POLY1305_SHA256
2026-10-20T08:31:11+00:00 client=172.16.181.1:64852 request="GET /mf0489-correlacion-01 HTTP/1.1" status=404 tls=TLSv1.3 cipher=TLS_CHACHA20_POLY1305_SHA256
```

Nginx sí ve la ruta porque es quien descifra. El 404 es normal: la app solo tiene la ruta `/`.

## 7. Correlación

Una sola petición con una ruta nueva: `/mf0489-correlacion-02`. La hice después de arreglar las alertas duplicadas (ver [§10](#10-dificultades)).

```
# Mac
HTTP 404 puerto_origen=50093
# Suricata (fast.log)
10/20/2026-08:45:25.120291 [1:1000003:2] MF0489 - Conexion HTTPS observada {TCP} 172.16.181.1:50093 -> 172.16.181.132:443
# Nginx
2026-10-20T08:45:25+00:00 client=172.16.181.1:50093 request="GET /mf0489-correlacion-02 HTTP/1.1" status=404 tls=TLSv1.3 cipher=TLS_CHACHA20_POLY1305_SHA256
```

| Campo | Cliente (Mac) | Suricata | Nginx |
|---|---|---|---|
| Hora (UTC) | 08:45:25 | 08:45:25.120 | 08:45:25 |
| IP cliente | — | 172.16.181.1 | 172.16.181.1 |
| **Puerto de origen** | **50093** | **50093** | **50093** |
| Destino | 172.16.181.132:443 | 172.16.181.132:443 | — |
| Evento | `curl` | SYN al 443, alerta SID 1000003 (una sola) | `GET /mf0489-correlacion-02` |
| Resultado | HTTP 404 | Alerta de laboratorio | `status=404` |
| TLS / HTTP visible | — | Conexión al 443. En el evento `tls`: versión y SNI. Sin ruta | TLS 1.3, `TLS_CHACHA20_POLY1305_SHA256`, ruta completa |

**¿Por qué son la misma prueba?** No me fío solo de la hora. Coinciden la IP, la hora al segundo y, sobre todo, el **puerto de origen 50093**, que el Mac elige al azar para cada conexión. Las tres fuentes están en UTC, así que no hubo que convertir horas. Docker no cambia la IP ni el puerto que recibe Nginx (la redirección la hace iptables y conserva el origen). La primera prueba (`/mf0489-correlacion-01`, puerto 64852) también cuadraba, pero con la alerta repetida.

Suricata no vio la ruta: ve la conexión y sus metadatos. La ruta solo la ve Nginx, que es quien descifra. Por eso hacen falta las dos fuentes.

## 8. Evento, alerta e incidente

| | ¿Pasó? | Por qué |
|---|---|---|
| **Evento** | Sí | Una conexión TCP al 443 y una petición `GET` que llegó a Nginx |
| **Alerta** | Sí | La regla 1000003 saltó |
| **Incidente** | No | La hice yo, desde mi Mac, contra mi laboratorio y sabiendo lo que iba a pasar. No hay nada comprometido ni ningún daño |

Una alerta solo dice "ha pasado algo que coincide con una regla". Para que sea incidente tiene que haber un impacto real o un intento no autorizado. Si cada alerta se tratara como incidente, el SOC no daría abasto con los falsos positivos.

## 9. Checklist final

| # | Comprobación | Resultado |
|---|---|---|
| 1 | HTTP sigue redirigiendo a HTTPS | ✅ `301` |
| 2 | HTTPS se verifica con `--cacert`, sin `-k` | ✅ |
| 3 | El nombre coincide con el certificado | ✅ `Verified peername` |
| 4 | Solo TLS 1.2 y 1.3 | ✅ |
| 5 | App y BBDD funcionan y conservan datos | ✅ 9 visitas guardadas |
| 6 | Solo 80 y 443 publicados, BBDD no expuesta | ✅ |
| 7 | Clave del servidor con 600 y montajes en solo lectura | ✅ `rw=false` en los tres montajes |
| 8 | `ca.key` fuera de Ubuntu y nada secreto en GitHub | ✅ |
| 9 | Suricata activo y reglas documentadas | ✅ |

## 10. Dificultades

| Problema | Causa | Solución |
|---|---|---|
| Las reglas activas de Suricata no eran las del repo | En el MF0488 se instalaron unas reglas en la VM y en GitHub quedaron otras | El `local.rules` del repo es ahora copia exacta de las activas más la nueva, y se instala con `sudo install` |
| La regla 1000003 no saltaba (rev:1 con `flags:S`) | `tcpdump` mostró que el Mac manda el SYN con `[SEW]`: SYN + bits ECN (CWR y ECE). `flags:S` exige SYN **solo** | `flags:S,CE` (rev:2). Antes de llevarlo a la VM lo probé con Suricata y una captura hecha a mano: un SYN normal y uno con ECN saltan, un SYN-ACK no |
| Aviso de `suricata -T`: `SYN-only … w/o direction specified` | La regla no decía la dirección | `flow:to_server` |
| TLS 1.1 daba `no protocols available` | Es el cliente (OpenSSL 3.5) quien se niega, no el servidor | Repetir con `SECLEVEL=0` para que la respuesta sea del servidor |
| `tcpdump` del 80 salía casi vacío | Con la salida en texto redirigida a un archivo, tcpdump guarda en memoria y escribe al terminar. Leí el archivo antes de que acabara (`-U` solo sirve con `-w`) | Leerlo cuando termina el `timeout`, o usar `-l` |
| Cada alerta salía **dos veces**, también las del MF0488 | Las dos copias tenían el mismo `flow_id`: era el mismo paquete procesado dos veces. El servicio arrancaba con `--af-packet -i enp2s0`, que monta dos capturas sobre `enp2s0` (en el log, `creating 1 thread` dos veces y `W: 2`). Lo reproduje en local con `--af-packet -i lo` | Drop-in de systemd ([`override.conf`](../../layer1-telemetry/suricata/override.conf)) que arranca solo con `--af-packet`. Ahora sale `W: 1` y una alerta por conexión. No toco el servicio del paquete, así no se pierde al actualizar. Sigue saliendo un aviso de `fanout` al arrancar, pero con una sola captura no afecta |
| `systemctl cat suricata` decía `Permission denied` con el override | Otra vez el `umask 077`: `sudo install -D` creó la carpeta `suricata.service.d` con 700 | systemd (root) la lee bien. Para verla: `sudo systemctl cat suricata` |
| Nginx no cogía el `default.conf` nuevo tras `git merge` | El archivo está montado suelto en el contenedor y git lo sustituye por uno nuevo | `docker compose restart reverse-proxy` |

## 11. Conclusión

**¿Cómo vigilo una web si no puedo leer sus peticiones HTTPS desde la red?** Con dos fuentes que se complementan:

| Fuente | Qué aporta |
|---|---|
| Suricata en la interfaz | Quién se conecta, cuándo, a qué puerto, con qué versión TLS y a qué nombre (SNI). Alertas por reglas |
| Log de Nginx (donde termina TLS) | Qué pidió (método, ruta, estado) y con qué cifrado |

Se unen por IP, hora y puerto de origen. El IDS no necesita descifrar nada y el contenido solo se ve en el punto donde ya es legítimo verlo.

## Normativa

| Referencia | Relación |
|---|---|
| ENS (RD 311/2022) op.mon.1 | Detección de intrusión: Suricata en la interfaz |
| ENS op.exp.8 / ISO 27001 A.8.15 | Registro de actividad: log de Nginx con TLS |
| ISO 27001 A.8.16 | Seguimiento de actividad y correlación de fuentes |
| ISO 27001 A.5.25 / NIS2 art. 23 | Valorar si un evento es incidente antes de tratarlo como tal |
| NIST SP 800-52r2 / CCN-STIC-807 | TLS 1.2 y 1.3, sin versiones antiguas |
