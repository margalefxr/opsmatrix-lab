# Guía de despliegue y recuperación

Cómo montar OpsMatrix desde cero, comprobar que funciona y recuperarlo si algo se rompe. No hace falta ninguna clave mía: cada uno genera las suyas.

## 1. Qué necesitas

| Equipo | Para qué | Software |
|---|---|---|
| Equipo de administración (en mi caso, el Mac) | CA y cliente de pruebas | OpenSSL 3, `curl`, `ssh` |
| Ubuntu Server (VM) | Servidor | Docker con Compose, OpenSSL, Suricata, `jq` |

Probado con Ubuntu 26.04 LTS, Docker 29.1.3, Compose 2.40.3, Suricata 8.0.3 y OpenSSL 3.5.5 en la VM, y OpenSSL 3.5.9 en el Mac ([`fase5-ssh-firewall-backup.txt`](evidencias/fase5/fase5-ssh-firewall-backup.txt), [`check-vm-github.txt`](evidencias/fase5/check-vm-github.txt), [`feedback-mf0488.txt`](evidencias/fase4/feedback-mf0488.txt), [`pki-salidas.txt`](evidencias/fase2/pki-salidas.txt)).

La CA **nunca** se crea en la VM. La VM se exportará como CTF y no puede llevar `ca.key`.

## 2. PKI (una vez)

Comandos completos y explicados en [fase2-pki.md](fase2-pki.md). Resumen:

| Paso | Dónde | Resultado |
|---|---|---|
| Crear la CA | Equipo de administración | `ca.key` (cifrada, 600) + `ca.crt` |
| Clave y CSR del servidor | VM | `servidor.key` (600) + `servidor.csr` con SAN `DNS:portal.opsmatrix.test` |
| Firmar con [`servidor.ext`](../../layer2-perimeter/pki/servidor.ext) | Equipo de administración | `servidor.crt` (1 año) |
| Instalar | VM | `/etc/ssl/private/servidor.key` (600), `/etc/ssl/certs/servidor.crt` (644), `/etc/ssl/mf0489/ca.crt` (644) |

## 3. Desplegar (VM)

```bash
git clone https://github.com/margalefxr/opsmatrix-lab.git
cd opsmatrix-lab
bash scripts/deploy.sh
```

[`deploy.sh`](../../scripts/deploy.sh) comprueba que estén los certificados, crea el `.env` con contraseñas aleatorias si no existe, valida el compose y levanta los tres contenedores.

**Suricata** (si se usa):

```bash
sudo install -m 644 layer1-telemetry/suricata/rules/local.rules /var/lib/suricata/rules/local.rules
sudo install -D -m 644 layer1-telemetry/suricata/override.conf /etc/systemd/system/suricata.service.d/override.conf
sudo systemctl daemon-reload
sudo suricata -T -c /etc/suricata/suricata.yaml && sudo systemctl restart suricata
```

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
| `ca.crl` | Equipo de administración y repo | Regenerar cada 30 días: `openssl ca -config ca.cnf -gencrl -crlexts ext_crl -out crl/ca.crl` |

**Copia de la BBDD** (también comprueba que se puede restaurar en una base aparte):

```bash
bash scripts/backup-db.sh
```

**Restaurar de verdad**:

```bash
gunzip -c ~/backups/opsmatrix-FECHA.sql.gz | docker compose exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'
```

**Volver a la configuración anterior** si un cambio rompe algo:

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
