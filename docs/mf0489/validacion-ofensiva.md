# Validación desde una máquina no confiable (Kali)

Hasta aquí he probado el sistema desde el Mac, que ya tiene mi CA. Aquí hago lo contrario: me pongo en la piel de alguien de fuera, en otra máquina (Kali) que **no** conoce mi CA, y compruebo que mis defensas aguantan. No es un ataque de verdad (ni exploto nada, ni pruebo contraseñas, ni tiro el servicio): es reconocimiento y sondeo contra mi propio laboratorio, que es justo lo que pide la Actividad 19 (comprobar que no he debilitado nada) y lo que cierra la historia del IDS de la Fase 4: cada cosa que hago desde fuera tiene que aparecer en Suricata.

Script: [`scripts/validacion-atacante.sh`](../../scripts/validacion-atacante.sh). Se lanza desde Kali:

```bash
bash scripts/validacion-atacante.sh 172.16.181.132 portal.opsmatrix.test
```

## Qué compruebo y qué tiene que pasar

| # | Qué hago desde fuera | Control que pongo a prueba | Resultado que espero | Alerta en Suricata |
|---|---|---|---|---|
| 1 | `ping` a la VM | Visibilidad del IDS en la red | Responde (no bloqueo ICMP a propósito) | SID 1000001 |
| 2 | Escaneo de puertos (`nmap`/`nc`) | Superficie expuesta | Solo 22, 80 y 443; 3306 y 5000 cerrados/filtrados | SID 1000002 (al 80), 1000003 (al 443) |
| 3 | HTTPS **sin** la CA | Cadena de confianza | Falla (`exit 60`): un extraño no confía en el certificado | 1000003 (la conexión sí entra) |
| 4 | HTTPS con `curl -k` | Qué gana saltándose la confianza | Ve la web, pero `-k` solo se engaña a sí mismo: no tiene la clave del servidor ni puede suplantarlo | 1000003 |
| 5 | Forzar TLS 1.0 y 1.1 | Protocolos obsoletos | El servidor corta el saludo (alerta 70) | 1000003 (el SYN entra; el handshake no se completa) |
| 6 | Conectar directo a 3306 y 5000 | Segmentación | No alcanzables: la BBDD y la app no salen al exterior | — (ni llegan al puerto) |
| 7 | Mirar la cabecera `Server` | Fuga de información | `Server: nginx`, sin versión (`server_tokens off`) | 1000002 |

## Resultado real (22/10/2026)

Lo lancé desde Kali, en `172.16.181.128` (otra máquina de la red, no el Mac). Salió todo como esperaba: [`validacion-atacante.txt`](evidencias/extras/validacion-atacante.txt).

| Paso | Resultado |
|---|---|
| 2 escaneo | `22/80/443 open`, `3306/5000 closed` |
| 3 HTTPS sin CA | `codigo=000 verificacion_tls=20`, `exit 60` |
| 4 `curl -k` | `codigo=200` (ve la web, pero no es mi servidor) |
| 5 TLS 1.0 y 1.1 | `alert number 70` en los dos: el servidor corta |
| 6 BBDD y app | `3306 no alcanzable`, `5000 no alcanzable` |
| 7 banner | `Server: nginx`, sin versión |

Y lo cacé en Suricata ([`validacion-suricata.txt`](evidencias/extras/validacion-suricata.txt)): las alertas con la IP de Kali (`172.16.181.128`) a las 09:43:06-08 coinciden con el ping (SID 1000001), el escaneo al 80 (1000002) y las conexiones al 443 (1000003). La IP del atacante en el IDS es la misma desde la que lancé el script (paso 0).

```
09:43:06.929372  [1:1000001:1] ... {ICMP} 172.16.181.128:8 -> 172.16.181.132:0
09:43:08.520581  [1:1000002:1] ... {TCP} 172.16.181.128:35050 -> 172.16.181.132:80
09:43:08.520581  [1:1000003:2] ... {TCP} 172.16.181.128:35050 -> 172.16.181.132:443
```

## Lo importante de esta prueba

- **La confianza no se puede falsificar.** Sin mi `ca.crt`, el atacante no puede validar el certificado (prueba 3). Y aunque use `-k` para ignorarlo (prueba 4), eso solo afecta a su propio cliente: no le da `servidor.key`, así que no puede hacerse pasar por mi servidor ante nadie que sí verifique. La clave privada nunca sale de la VM (Fase 2).
- **Lo que no está publicado, no se ataca.** La BBDD (3306) y la app (5000) ni siquiera aparecen en el escaneo (pruebas 2 y 6), porque solo el proxy publica puertos y la BBDD está en una red `internal`. Esto es lo mismo que compruebo desde dentro en el aislamiento de la [Fase 4](fase4-auditoria-tls-monitorizacion.md#9-checklist-final), pero ahora visto desde fuera.
- **No hay versiones viejas de TLS que explotar** (prueba 5): el servidor rechaza 1.0 y 1.1, como en la [Fase 4 §3](fase4-auditoria-tls-monitorizacion.md#3-versiones-tls).
- **Veo al atacante.** Todo lo que hace deja rastro en Suricata. En la VM, mientras lanzo el script:

```bash
sudo grep -E "1000001|1000002|1000003" /var/log/suricata/fast.log | tail -20
```

Correlaciono igual que en la [Fase 4 §7](fase4-auditoria-tls-monitorizacion.md#7-correlación): la IP de Kali en las alertas tiene que coincidir con la IP desde la que lancé el script (paso 0).

## Lo que NO cubre esta prueba (y por qué)

- No es un pentest completo: no pruebo fuerza bruta de SSH, inyección en la app ni fuzzing. Son otro trabajo y se saldrían del alcance del MF0489.
- Que todo salga como espero no demuestra que el sistema sea inexpugnable; demuestra que los controles de este módulo (TLS, segmentación, mínima exposición, IDS) hacen lo que digo que hacen, y que un extraño sin mi CA se queda fuera.
