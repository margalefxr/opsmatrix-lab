# Extra — Revocación e inventario criptográfico

La rúbrica pide construir la PKI. Esto va un paso más allá: qué pasa cuando algo sale mal (revocación) y qué criptografía hay exactamente en el proyecto (inventario). Son dos cosas que el sector está empujando ahora:

| Tendencia | Por qué importa |
|---|---|
| Vuelven las CRL | Let's Encrypt apagó OCSP en 2025 y el CA/B Forum lo dejó opcional. La revocación vuelve a ir por listas (CRL) |
| Inventario criptográfico (CBOM) | Es el primer paso de la migración post-cuántica que piden la UE y el NIST: no se puede migrar lo que no sabes que tienes |

## 1. Revocación

**¿Qué pasaba antes?** La CA puede firmar listas de revocación (`cRLSign`), pero no había ninguna. Si alguien robaba `servidor.key`, el certificado seguía siendo válido hasta 2027 y no había forma de anularlo.

**Qué hice** ([`pki-revocacion.sh`](../../scripts/pki-revocacion.sh), en el Mac, donde está la CA):

| Paso | Para qué |
|---|---|
| [`ca.cnf`](../../layer2-perimeter/pki/ca.cnf) con base de datos (`index.txt`) | Que la CA lleve registro de lo que firma. Con `openssl x509 -req` (Fase 2) no lo llevaba |
| Registrar `servidor.crt` (`openssl ca -valid`) | El certificado real queda apuntado como válido |
| Emitir `prueba-revocacion.opsmatrix.test` y revocarlo con motivo `keyCompromise` | Simular una clave robada sin tocar el certificado real |
| Publicar la CRL ([`ca.crl`](../../layer2-perimeter/pki/ca.crl), válida 30 días) | Lista firmada de lo revocado. Es pública |

```
V  271019102324Z                           0132A8F5…F1  /CN=portal.opsmatrix.test
R  271020110032Z  261020110035Z,keyCompromise  3C3D0720…23  /CN=prueba-revocacion.opsmatrix.test

$ openssl verify -crl_check -CAfile ca.crt -CRLfile crl/ca.crl emitidos/prueba.crt
error 23 at 0 depth lookup: certificate revoked
$ openssl verify -crl_check -CAfile ca.crt -CRLfile crl/ca.crl -purpose sslserver -verify_hostname portal.opsmatrix.test emitidos/servidor.crt
emitidos/servidor.crt: OK
$ openssl s_client -connect 172.16.181.132:443 … -CRL crl/ca.crl -crl_check
Verification: OK
```

El revocado se rechaza (error 23) y el real sigue valiendo, también en la conexión a Nginx. Salida completa: [`pki-revocacion.txt`](evidencias/pki-revocacion.txt).

**Qué hacer si se filtra una clave:**

| Se filtra | Pasos |
|---|---|
| `servidor.key` | 1. Revocar `servidor.crt` (`openssl ca -revoke … -crl_reason keyCompromise`) y publicar la CRL. 2. Clave y CSR nuevas en la VM. 3. Firmar e instalar (Fase 2). 4. `docker compose restart reverse-proxy`. 5. Revisar logs de Nginx y Suricata desde la fecha del robo |
| `ca.key` | Todo lo firmado deja de ser fiable. CA nueva, reemitir el certificado del servidor, repartir el nuevo `ca.crt` y quitar el viejo de todos los equipos que confíen en él |

**Límite:** `servidor.crt` no lleva la dirección donde descargar la CRL (`crlDistributionPoints`), así que hoy el cliente tiene que recibirla a mano (`-CRLfile`, `curl --crlfile`). En la próxima emisión la añadiría a `servidor.ext` y Nginx serviría la CRL.

## 2. Inventario criptográfico

| Activo | Algoritmo | Dónde | Caduca | ¿Aguanta un ordenador cuántico? | Siguiente paso |
|---|---|---|---|---|---|
| CA raíz | RSA 4096, SHA-256. Clave cifrada con AES-256 | Mac | 16/10/2036 | ❌ RSA | Pasar a ML-DSA cuando los clientes lo acepten. OpenSSL 3.5 ya genera esas claves |
| Certificado del servidor | RSA 3072, SHA-256 | VM, `/etc/ssl/` | 19/10/2027 | ❌ RSA | Renovar antes de esa fecha |
| CRL | Firmada por la CA (RSA 4096, SHA-256) | Mac y repo | Siguiente: 19/11/2026 | — | Regenerar cada mes. Si caduca, los clientes que la comprueban fallan |
| TLS 1.3 | `X25519MLKEM768` + AES-256-GCM / ChaCha20-Poly1305 | Nginx | Por conexión | ✅ Híbrido | — |
| TLS 1.2 | ECDHE X25519 + AES-256-GCM | Nginx | Por conexión | ❌ | Mantener solo por compatibilidad |
| SSH | Intercambio `ecdh-sha2-nistp256`, clave del host Ed25519 | VM | — | ❌ | Ver abajo |
| Contraseñas de la BBDD | Aleatorias, 24 bytes (`openssl rand`) | `.env` (600) | — | ✅ | Cambiarlas si hay incidente |
| Copias de la BBDD | gzip, **sin cifrar** | `~/backups` (600) | — | — | Cifrarlas (`age` o `gpg`) |
| App ↔ MariaDB | Sin TLS | Red interna | — | — | Límite documentado en la Fase 1 |

**Hallazgo SSH.** El servidor es OpenSSH 10.2, que ya soporta intercambio post-cuántico (`mlkem768x25519-sha256`). Aun así, la conexión desde el Mac negoció `ecdh-sha2-nistp256`, clásico. Lo decide la lista de algoritmos que ofrece el cliente. No lo fuerzo en el servidor porque, si el cliente del Mac no lo soporta, me quedaría fuera. Siguiente paso: `ssh -Q kex` en el Mac y, si sale `mlkem768x25519-sha256`, ponerlo el primero en `~/.ssh/config`.

## Normativa

| Referencia | Relación |
|---|---|
| ISO 27001 A.8.24 | Ciclo de vida de las claves: también revocarlas |
| ISO 27001 A.5.26 | Respuesta a incidentes: qué hacer si se filtra una clave |
| ENS op.exp.10 | Protección de claves criptográficas |
| RFC 5280 §5 | Formato de las CRL |
| Hoja de ruta PQC de la UE (2025) | Inventario como primer paso de la migración |
