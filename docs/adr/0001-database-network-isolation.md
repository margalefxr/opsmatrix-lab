# ADR 0001: Aislamiento Criptográfico y de Red para la Capa de Persistencia (MariaDB)

* **Estatus:** Aceptado
* **Fecha:** 2026-09-15
* **Autor:** Xavier Margalef Riestra
* **Contexto Técnico:** Configuración de red para el contenedor MariaDB en la infraestructura `OpsMatrix-Lab`.

---

## 1. Contexto & Planteamiento del Problema
La aplicación SaaS requiere almacenar datos transaccionales ficticios de usuarios. Debemos decidir la exposición de red del servicio de base de datos dentro del host Ubuntu Server 24.04 LTS, garantizando que cumple con el principio de Mínimo Privilegio (Least Privilege) y Zero Trust.

---

## 2. Alternativas Evaluadas (A vs. B vs. C)

### Opción A: Exposición Directa de Puertos en el Host (`ports: "3306:3306"`)
* **Descripción:** Mapear el puerto de MariaDB al puerto físico del servidor base.
* **Pros:** Permite administración directa desde herramientas externas (e.g., DBeaver, MySQL Workbench) desde la máquina del administrador.
* **Contras:** **Inaceptable a nivel SecOps.** Expone el motor de base de datos a vectores de ataque directo (fuerza bruta SSH/MySQL tunneling, vulnerabilidades Zero-Day del motor SQL) desde la interfaz de red pública/externa.

### Opción B: Exposición Limitada al Loopback del Host (`ports: "127.0.0.1:3306:3306"`)
* **Descripción:** Bindear el puerto 3306 exclusivamente a la interfaz local del servidor (`127.0.0.1`).
* **Pros:** Evita la exposición a la red externa; solo procesos locales del host pueden conectarse.
* **Contras:** Un atacante que logre ejecución remota de comandos (RCE) o acceso SSH limitado al host físico puede interactuar directamente con el socket de la base de datos sin pasar por el WAF/Proxy.

### Opción C: Red Privada Aislada Docker Bridge (`internal: true`) — [Elegida]
* **Descripción:** Crear una subred interna gestionada por Docker donde MariaDB opera sin mapeo de puertos (`ports:` omitido) y marcada como `internal: true`.
* **Pros:**
  1. Aisle absoluto: La base de datos no tiene ruta por defecto (default gateway) hacia internet ni es alcanzable directamente desde la red del Host.
  2. Alineación Zero Trust: La única forma de consultar la base de datos es a través del contenedor Nginx ( Reverse Proxy / App Gateway) ubicado en la misma subred bridge.
* **Contras:** La administración directa requiere comandos vía `docker exec` o túneles de aplicación dedicados.

---

## 3. Decisión Final & Justificación de Bajo Nivel
Se selecciona la **Opción C**. La base de datos operará en la subred aislada `backend_net`. 

A nivel de kernel de Linux, Docker genera reglas de `iptables` en la cadena `DOCKER-USER`. Al marcar la red como `internal: true`, Docker bloquea el reenvío de paquetes (forwarding) hacia la interfaz física del host, garantizando que el contenedor MariaDB no pueda iniciar conexiones salientes ni recibir tráfico no originado en el bridge interno.

---

## 4. Consecuencias & Evidencias para Auditoría
* **Superficie de Ataque:** Reducida a TCP 80/443 (Nginx) y TCP 22 (SSH).
* **Trazabilidad:** Cualquier intento de acceso a la base de datos queda registrado obligatoriamente en los logs de aplicación de Nginx y no mediante tráfico IP directo.
