# Guía de despliegue y recuperación

Cómo montar OpsMatrix desde cero, comprobar que funciona y recuperarlo si algo se rompe. No hace falta ninguna clave mía: cada uno genera las suyas.

## 1. Qué necesitas

| Equipo | Para qué | Software |
|---|---|---|
| Equipo de administración (en mi caso, el Mac) | CA y cliente de pruebas | OpenSSL 3, `curl`, `ssh` |
| Ubuntu Server (VM) | Servidor | Docker con Compose, OpenSSL, Suricata, `jq` |

Probado con Ubuntu 26.04 LTS, Docker 29.1.3, Compose 2.40.3, Suricata 8.0.3 y OpenSSL 3.5.5 en la VM, y OpenSSL 3.5.9 en el Mac ([`fase5-ssh-firewall-backup.txt`](evidencias/fase5/fase5-ssh-firewall-backup.txt), [`check-vm-github.txt`](evidencias/fase5/check-vm-github.txt), [`feedback-mf0488.txt`](evidencias/fase4/feedback-mf0488.txt), [`pki-salidas.txt`](evidencias/fase2/pki-salidas.txt)).

La CA **nunca** se crea en la VM. La VM se exportará como CTF y no puede llevar `ca.key`.

**Si tu laboratorio es distinto** (todo lo demás funciona igual):

| Si cambias… | Edita |
|---|---|
| La IP de la VM (aquí `172.16.181.132`) | `IP=` arriba de `check-mac.sh`, `fase4-mac.sh` y `pki-revocacion.sh` |
| La carpeta de la CA (aquí `~/ca_root-pki/ca`) | `CA_DIR=` arriba de esos mismos scripts |
| El nombre (aquí `portal.opsmatrix.test`) | `server_name` en `default.conf`, `subjectAltName` en `servidor.ext`, la CSR y `D=` arriba de los scripts |

## 2. PKI (una vez, con tus propias claves)

Cada uno crea su CA y sus claves. Las mías no hacen falta ni se publican. Explicación de cada comando y de cada extensión en [fase2-pki.md](fase2-pki.md). Los he probado tal cual desde un clon limpio ([`replica-desde-cero.txt`](evidencias/fase5/replica-desde-cero.txt)). Cambia `USUARIO@IP_VM` por los tuyos.

**Equipo de administración: crear la CA**

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git ~/opsmatrix-lab
umask 077
mkdir -p ~/ca_root-pki/ca/private ~/ca_root-pki/ca/solicitudes ~/ca_root-pki/ca/emitidos
cd ~/ca_root-pki/ca
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc -out private/ca.key   # pide una contraseña
chmod 600 private/ca.key
openssl pkey -in private/ca.key -check -noout                  # "Key is valid"
openssl req -x509 -new -sha256 -days 3650 -key private/ca.key -out ca.crt \
  -subj "/C=ES/O=OpsMatrix Lab/CN=OpsMatrix Lab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash"
cp ~/opsmatrix-lab/layer2-perimeter/pki/servidor.ext .
openssl verify -CAfile ca.crt ca.crt
```

**VM: clave y CSR del servidor** (la clave no sale de la VM)

```bash
umask 077
mkdir -p ~/mf0489 && cd ~/mf0489
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out servidor.key
chmod 600 servidor.key
openssl req -new -sha256 -key servidor.key -out servidor.csr \
  -subj "/CN=portal.opsmatrix.test" -addext "subjectAltName=DNS:portal.opsmatrix.test"
```

**Equipo de administración: revisar la CSR, firmarla y devolver el certificado** (solo viajan archivos públicos)

```bash
cd ~/ca_root-pki/ca
scp USUARIO@IP_VM:mf0489/servidor.csr solicitudes/
openssl req -in solicitudes/servidor.csr -noout -verify -subject      # tiene que decir CN=portal.opsmatrix.test
openssl x509 -req -in solicitudes/servidor.csr -CA ca.crt -CAkey private/ca.key \
  -CAcreateserial -out emitidos/servidor.crt -days 365 -sha256 -extfile servidor.ext
scp emitidos/servidor.crt ca.crt USUARIO@IP_VM:mf0489/
```

**VM: instalar y comprobar**

```bash
cd ~/mf0489
sudo install -d -m 755 /etc/ssl/mf0489        # con -d y 755: si no, el umask 077 la deja ilegible (me pasó)
sudo install -o root -g root -m 600 servidor.key /etc/ssl/private/servidor.key
sudo install -o root -g root -m 644 servidor.crt /etc/ssl/certs/servidor.crt
sudo install -o root -g root -m 644 ca.crt       /etc/ssl/mf0489/ca.crt
openssl verify -CAfile /etc/ssl/mf0489/ca.crt -purpose sslserver \
  -verify_hostname portal.opsmatrix.test /etc/ssl/certs/servidor.crt   # tiene que dar OK
rm servidor.key                                # la copia de trabajo ya no hace falta
```

`check-mac.sh` espera esta misma estructura en el equipo de administración (`private/ca.key`, `ca.crt`, `emitidos/servidor.crt`).

## 3. Desplegar (VM)

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/deploy.sh
```

[`deploy.sh`](../../scripts/deploy.sh) comprueba que estén los certificados, crea el `.env` con contraseñas aleatorias si no existe, valida el compose y levanta los tres contenedores. Probado desde un clon limpio de GitHub, con `.env` y BBDD nuevos ([`prueba-limpia-vm.txt`](evidencias/fase5/prueba-limpia-vm.txt), [`prueba-limpia-mac.txt`](evidencias/fase5/prueba-limpia-mac.txt)).

**Suricata** (si se usa). El `suricata.yaml` que trae Ubuntu escucha en `eth0` y no carga `local.rules`: sin estos dos cambios no salta ninguna regla, y `suricata -T` da OK igualmente ([`suricata-desde-cero.txt`](evidencias/fase5/suricata-desde-cero.txt)).

```bash
IFAZ=enp2s0                                   # tu interfaz: ip -br a
sudo sed -i "s/^\(\s*- interface:\) eth0$/\1 $IFAZ/" /etc/suricata/suricata.yaml
grep -q "^  - local.rules$" /etc/suricata/suricata.yaml || \
  sudo sed -i 's/^  - suricata.rules$/&\n  - local.rules/' /etc/suricata/suricata.yaml
grep -n "HOME_NET:" /etc/suricata/suricata.yaml   # tiene que incluir la IP de la VM
sudo install -m 644 layer1-telemetry/suricata/rules/local.rules /var/lib/suricata/rules/local.rules
sudo install -D -m 644 layer1-telemetry/suricata/override.conf /etc/systemd/system/suricata.service.d/override.conf
sudo systemctl daemon-reload
sudo suricata -T -c /etc/suricata/suricata.yaml && sudo systemctl restart suricata
```

Para saber que detecta de verdad: `ping -c 1 IP_VM` desde el cliente y `sudo grep 1000001 /var/log/suricata/fast.log | tail -1` en la VM. Tiene que salir la alerta.

**SSH solo con clave.** Primero copia tu clave con `ssh-copy-id` y comprueba que entras sin contraseña. **Solo entonces**:

```bash
sudo install -m 644 layer2-perimeter/ssh/00-opsmatrix.conf /etc/ssh/sshd_config.d/00-opsmatrix.conf
sudo sshd -t && sudo systemctl reload ssh
```

## 4. Comprobar

| Dónde | Comando | Debe salir |
|---|---|---|
| VM | `bash scripts/check-vm.sh` | Contenedores `Up`, solo 22/80/443 abiertos, `OK` en certificados y secretos |
| Cliente | `bash scripts/check-mac.sh` (cambiar `IP` y `CA_DIR` arriba) | `301`, `200` con la CA, `exit 60` sin ella, TLS 1.1 rechazado |

En el navegador: añadir `IP_VM portal.opsmatrix.test` a `/etc/hosts` e importar `ca.crt` como CA de confianza solo en el equipo de pruebas.

## 5. Copias y recuperación

| Qué | Dónde está la copia | Cómo se recupera |
|---|---|---|
| Código y configuración | git (GitHub) | `git clone` + `deploy.sh` |
| Base de datos | `~/backups/opsmatrix-FECHA.sql.gz` en la VM (fuera del repo, 600) | Ver abajo |
| `.env` | Solo en la VM | Si se pierde, se puede crear uno nuevo, pero la BBDD guardada tiene las contraseñas antiguas: restaurar desde copia o cambiar la contraseña en MariaDB |
| `servidor.key` / `servidor.crt` | Solo en la VM | Si se ha filtrado, revocarlo primero ([procedimiento](extras.md#3-revocación)). Luego clave y CSR nuevas y firmar de nuevo (Fase 2) |
| `ca.key` | Solo en el equipo de administración | Si se pierde o se filtra: CA nueva, reemitir `servidor.crt` y repartir el nuevo `ca.crt` |
| `ca.crl` | Equipo de administración y repo | La primera vez la crea [`pki-revocacion.sh`](../../scripts/pki-revocacion.sh) (prepara `ca.cnf`, `index.txt` y `crl/`). Después, regenerar cada 30 días en `~/ca_root-pki/ca`: `openssl ca -config ca.cnf -gencrl -crlexts ext_crl -out crl/ca.crl` |

**Copia de la BBDD** (también comprueba que se puede restaurar en una base aparte):

```bash
bash scripts/backup-db.sh
```

**Restaurar de verdad** (no lo he hecho sobre la BBDD buena para no arriesgarla; lo probado es la misma restauración en `restore_test`, que hace `backup-db.sh`):

```bash
gunzip -c ~/backups/opsmatrix-FECHA.sql.gz | docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'
```

**Volver a la configuración anterior** si un cambio rompe algo (procedimiento, no lo he necesitado):

```bash
git log --oneline            # elegir el commit bueno
git checkout <commit> -- docker-compose.yml layer2-perimeter/nginx/default.conf
docker compose up -d --force-recreate
```

## 6. Problemas conocidos

| Síntoma | Causa | Solución |
|---|---|---|
| `pip install` falla al construir: `Temporary failure in name resolution` | `docker0` sin IP | `ip -4 addr show docker0`. Si no tiene IP: `sudo systemctl restart docker` |
| La app se reinicia con `Permission denied` en `app.py` | Repo clonado con `umask 077` | Ya resuelto en el Dockerfile (`chmod 644`). Reconstruir: `docker compose up -d --build` |
| Nginx no coge un `default.conf` nuevo | Archivo montado suelto, git lo sustituye | `docker compose restart reverse-proxy` |
| Alertas de Suricata duplicadas | Servicio arrancado con `--af-packet -i enp2s0` | Instalar `override.conf` (punto 3) |

## 7. Lo que nunca va al repo

`ca.key`, `servidor.key`, `.env`, copias de la BBDD (`*.sql*`, `backups/`) y la OVA. Lo impide el [`.gitignore`](../../.gitignore). Ojo: `.gitignore` no saca del historial algo que ya se subió. Si pasa, hay que cambiar ese secreto.
