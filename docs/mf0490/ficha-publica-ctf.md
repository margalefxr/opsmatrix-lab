# OpsMatrix — reto Boot2Root

## De qué va
OpsMatrix es el portal seguro de una gestoría: el sitio donde sus clientes (autónomos y pequeñas empresas) consultan su documentación. Lo monté y lo endurecí en los módulos anteriores, y para este reto le he dejado un par de fallos de administración metidos a propósito. Tu trabajo es entrar y hacerte con la máquina.

## Objetivo
Conseguir las dos banderas:

- `user.txt` — en el directorio personal del usuario con el que logres entrar.
- `root.txt` — en `/root/`, solo accesible cuando seas root del sistema.

Las dos tienen el formato `OPSMTX{...}`.

## Cómo conectar
- La máquina está en la red aislada del laboratorio. Pídele al organizador la IP que le ha tocado.
- Es un Ubuntu Server. El portal se publica por HTTPS en el 443 con un certificado propio, así que el navegador o `curl` se van a quejar del certificado: es normal, lo aceptas (`curl -k`).
- No necesitas internet ni contraseñas de antemano. Todo lo que hace falta está en la propia máquina.

## Reglas del reto
- Es un entorno de prácticas en red aislada. No lo saques a internet.
- Hay una ruta principal con dos etapas: primero conseguir un usuario normal del sistema y luego subir a root.
- No hay que romper el kernel ni escapar de ningún contenedor. Con enumerar bien y mirar la configuración del sistema llega.
- Con herramientas estándar (nmap, curl, ssh) te sobra.

Suerte con él.
