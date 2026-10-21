# Fase 2 — PKI con OpenSSL

Monto una CA de laboratorio y emito con ella el certificado del servidor `portal.opsmatrix.test`. Todas las salidas son reales, del 19/10/2026. Salidas sin recortar: [`evidencias/fase2/pki-salidas.txt`](evidencias/fase2/pki-salidas.txt).

## Resumen

| Criterio | Pts | Evidencia |
|---|---|---|
| F2.1 CA separada, `ca.key` cifrada y fuera de la VM | 0,45 | [§1](#1-entornos) · [§2](#2-ca-raíz-mac) |
| F2.2 CA raíz: autofirmada, `CA:TRUE`, `pathlen:0`, usos de firma | 0,50 | [§2](#2-ca-raíz-mac) |
| F2.3 Clave del servidor y CSR con SAN verificada | 0,45 | [§3](#3-clave-y-csr-del-servidor-vm) |
| F2.4 Certificado firmado: Subject/Issuer, `CA:FALSE`, `serverAuth`, SAN | 0,65 | [§4](#4-firma-del-certificado-mac) |
| F2.5 Verificación: con/sin CA, nombre incorrecto, vigencia, clave ↔ certificado | 0,65 | [§5](#5-instalación-y-verificación-vm) |
| F2.6 Instalación en `/etc/ssl/` y permisos | 0,30 | [§5](#5-instalación-y-verificación-vm) |

## 1. Entornos

| | Entorno A — CA | Entorno B — Servidor |
|---|---|---|
| Máquina | Mac (fuera de la VM) | Ubuntu Server `ubuntuserver` (futura VM CTF) |
| IP | 172.16.181.1 | 172.16.181.132 (`enp2s0`) |
| OpenSSL | 3.5.9 | 3.5.5 |
| Ruta de trabajo | `~/ca_root-pki/ca/` | `~/mf0489/` (temporal) → `/etc/ssl/` |
| Claves privadas | `ca.key` | `servidor.key` |

**Nombre DNS:** `portal.opsmatrix.test`. `.test` está reservado para pruebas (RFC 6761).

**Qué viaja entre máquinas:** solo la CSR (VM → Mac) y los certificados públicos (Mac → VM), por `scp`. Ninguna clave privada sale de su máquina.

| Archivo | Por qué no se mueve |
|---|---|
| `ca.key` | Quien la tenga puede firmar certificados de confianza para cualquier dominio. La VM se exportará como CTF |
| `servidor.key` | Quien la tenga puede hacerse pasar por el servidor. La CA no la necesita: firma la clave **pública** que va dentro de la CSR |

## 2. CA raíz (Mac)

```bash
umask 077
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc -out private/ca.key
openssl req -x509 -new -sha256 -days 3650 -key private/ca.key -out ca.crt \
  -subj "/C=ES/O=OpsMatrix Lab/CN=OpsMatrix Lab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash"
```

```
-rw-------@ 1 xaviermargalef  staff  3446 19 oct.  12:21 private/ca.key
Key is valid
subject=C=ES, O=OpsMatrix Lab, CN=OpsMatrix Lab Root CA
issuer=C=ES, O=OpsMatrix Lab, CN=OpsMatrix Lab Root CA
notBefore=Oct 19 10:21:23 2026 GMT
notAfter=Oct 16 10:21:23 2036 GMT
X509v3 Basic Constraints: critical
    CA:TRUE, pathlen:0
X509v3 Key Usage: critical
    Certificate Sign, CRL Sign
        Signature Algorithm: sha256WithRSAEncryption
                Public-Key: (4096 bit)
ca.crt: OK
```

| Campo | Valor | Significado |
|---|---|---|
| Subject = Issuer | `OpsMatrix Lab Root CA` | Coinciden porque es autofirmada: es la raíz, nadie la firma por encima |
| `CA:TRUE, pathlen:0` | Crítico | Puede firmar certificados de servidor, pero no crear CA intermedias |
| Key Usage | `keyCertSign, cRLSign` | Solo sirve para firmar certificados y listas de revocación |
| Clave | RSA 4096, cifrada con AES-256, permisos 600 | Robada sin la contraseña no sirve |
| Firma / validez | SHA-256 / 10 años | Lo habitual en una raíz, que se renueva poco |

`ca.crt: OK` solo confirma que la CA es coherente consigo misma. No significa que ningún navegador u ordenador confíe en ella.

## 3. Clave y CSR del servidor (VM)

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out servidor.key
openssl req -new -sha256 -key servidor.key -out servidor.csr \
  -subj "/CN=portal.opsmatrix.test" -addext "subjectAltName=DNS:portal.opsmatrix.test"
```

```
-rw------- 1 server server 2484 Oct 19 10:22 servidor.key
Certificate request self-signature verify OK
subject=CN=portal.opsmatrix.test
                X509v3 Subject Alternative Name:
                    DNS:portal.opsmatrix.test
                Public-Key: (3072 bit)
```

La firma de la CSR es válida, el CN y el SAN llevan el dominio y dentro va la clave pública de 3072 bits. La clave del servidor **no lleva contraseña** para que Nginx pueda arrancar solo; la protegen los permisos `600` y el acceso a la VM.

## 4. Firma del certificado (Mac)

Antes de firmar, la CA revisa la CSR: `Certificate request self-signature verify OK`, `subject=CN=portal.opsmatrix.test`. Una CA no firma lo que le llegue sin mirar el nombre.

[`servidor.ext`](../../layer2-perimeter/pki/servidor.ext):

```ini
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:portal.opsmatrix.test
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
```

```bash
openssl x509 -req -in solicitudes/servidor.csr -CA ca.crt -CAkey private/ca.key \
  -CAcreateserial -out emitidos/servidor.crt -days 365 -sha256 -extfile servidor.ext
```

```
subject=CN=portal.opsmatrix.test
issuer=C=ES, O=OpsMatrix Lab, CN=OpsMatrix Lab Root CA
notBefore=Oct 19 10:23:24 2026 GMT
notAfter=Oct 19 10:23:24 2027 GMT
X509v3 Basic Constraints: critical
    CA:FALSE
X509v3 Key Usage: critical
    Digital Signature, Key Encipherment
X509v3 Extended Key Usage:
    TLS Web Server Authentication
X509v3 Subject Alternative Name:
    DNS:portal.opsmatrix.test
```

| Extensión | Para qué |
|---|---|
| `CA:FALSE` | Es un certificado final: no puede firmar otros |
| `serverAuth` | Solo vale para identificar un servidor TLS |
| SAN `DNS:portal.opsmatrix.test` | Es lo que comprueban los clientes. El CN ya no se usa para validar el nombre |
| `subjectKeyIdentifier` / `authorityKeyIdentifier` | Huellas que encadenan el certificado con su CA. Aquí el AKI del servidor (`71:F1:48:5D…`) es el SKI de la CA ([comprobado](evidencias/fase5/coherencia-docs-codigo.txt)) |

`servidor.ext` se pone en la firma porque la CA decide qué extensiones lleva el certificado final. Las de la CSR no se copian solas.

Transferencias (solo archivos públicos):

```
# VM → Mac
servidor.csr                          100% 1322
# Mac → VM, a ~/mf0489/
servidor.crt                          100% 1809
ca.crt                                100% 1964
```

## 5. Instalación y verificación (VM)

```bash
sudo install -o root -g root -m 600 ~/mf0489/servidor.key /etc/ssl/private/servidor.key
sudo install -o root -g root -m 644 ~/mf0489/servidor.crt /etc/ssl/certs/servidor.crt
sudo install -o root -g root -m 644 ~/mf0489/ca.crt     /etc/ssl/mf0489/ca.crt
```

```
-rw------- 1 root root 2484 Oct 19 10:26 /etc/ssl/private/servidor.key
-rw-r--r-- 1 root root 1809 Oct 19 10:26 /etc/ssl/certs/servidor.crt
drwxr-xr-x 2 root root 4096 Oct 19 10:26 /etc/ssl/mf0489
-rw-r--r-- 1 root root 1964 Oct 19 10:26 /etc/ssl/mf0489/ca.crt
```

| Comprobación | Resultado real | Interpretación |
|---|---|---|
| CA raíz con su propio certificado | `ca.crt: OK` | La CA es coherente |
| Verificación sin confiar en la CA | `error 20 … unable to get local issuer certificate` | El sistema no conoce la CA. El certificado no está mal, falta el ancla de confianza |
| Verificación con `-CAfile` | `/etc/ssl/certs/servidor.crt: OK` | La cadena es correcta. Con `-purpose sslserver -verify_hostname` y la CRL también da `OK` ([validación](evidencias/fase5/validacion-herramientas.txt)) |
| SAN coincide con el DNS | `DNS:portal.opsmatrix.test` | ✅ |
| Nombre incorrecto `servidor-equivocado.test` | `error 62 … hostname mismatch` | Firmado bien, pero no identifica a ese servidor. Además de la firma, el nombre tiene que coincidir |
| Vigencia | `notAfter=Oct 19 10:23:24 2027 GMT` · `Certificate will not expire` | Vigente |
| Clave ↔ certificado | `4a232ee3d9b7e1e4…172ae4` en los dos | La clave instalada es la del certificado |

Después borré la copia temporal: `rm ~/mf0489/servidor.key`. En `~/mf0489/` solo quedan `ca.crt`, `servidor.crt` y `servidor.csr` (comprobado después con `ls`, en [`check-vm.txt`](evidencias/fase3/check-vm.txt)).

## Archivos públicos en el repo

En [`layer2-perimeter/pki/`](../../layer2-perimeter/pki/): `ca.crt`, `servidor.csr`, `servidor.crt` y `servidor.ext`. Son copias para documentar. Nginx usará los de `/etc/ssl/` de la VM. El `.gitignore` excluye `**/*.key`, `**/private/`, `.env`, `*.p12`, `*.pfx` y `*.pem`.

## Decisiones

| Decisión | Motivo |
|---|---|
| RSA 4096 en la CA, 3072 en el servidor | La raíz dura 10 años y merece más margen. 3072 equivale a ~128 bits de seguridad (NIST SP 800-57) y es suficiente para un certificado de 1 año |
| `ca.key` cifrada con AES-256 | Si alguien copia el archivo, sin la contraseña no puede firmar |
| `servidor.key` sin contraseña | Nginx tiene que arrancar solo. La protegen los permisos 600 y el acceso a la VM |
| `-addext` en la CSR y `servidor.ext` en la firma | El SAN lo pide el servidor, pero quien decide qué se firma es la CA |
| Certificado de 1 año | Menos tiempo de exposición si la clave se compromete |

## Dificultades

| Dificultad | Solución |
|---|---|
| `Permission denied` al leer `/etc/ssl/mf0489/ca.crt`, aunque el archivo tenía `644` | El `umask 077` de la sesión lo heredó `sudo mkdir`, que creó la carpeta con `700`. Arreglado con `sudo chmod 755 /etc/ssl/mf0489` |
| El `.gitignore` anterior excluía `*.crt` y no dejaba publicar `ca.crt` ni `servidor.crt` | Cambiado: ahora excluye claves y secretos, no certificados públicos |
| En el repo había restos de MF0488 (`ca.srl` y un `server.csr` antiguo autofirmado) | Eliminados. Los sustituye la PKI nueva |
| El `scp` de la VM aceptó contraseña, cuando el README dice "solo Ed25519" | Anotado. Resuelto en la [Fase 5](fase5-entrega-final.md#2-qué-corre-de-verdad): clave autorizada y `PasswordAuthentication no` |

## Normativa

| Referencia | Relación |
|---|---|
| ISO 27001 A.8.24 | Uso de criptografía: algoritmos, tamaños de clave y ciclo de vida de claves |
| ENS (RD 311/2022) op.exp.10 | Protección de claves criptográficas: custodia de `ca.key` fuera de la VM |
| NIST SP 800-57 | RSA 3072 ≈ 128 bits de seguridad; tamaño mínimo recomendado a partir de 2030 |
| RFC 5280 | Perfil X.509: `basicConstraints`, `keyUsage`, `extKeyUsage`, SAN, SKI/AKI |
| CCN-STIC-807 | Guía del CCN con los algoritmos y longitudes de clave admitidos en el ENS |
