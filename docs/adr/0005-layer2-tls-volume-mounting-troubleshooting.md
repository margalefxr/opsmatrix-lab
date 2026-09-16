# ADR-005: Correccion de Montaje de Volumenes y Terminacion TLS 1.3 en Nginx

* Fecha: 2026-09-16
* Estado: Aceptado

## Contexto
Durante el despliegue de la Capa 2 (Perimetro), la negociacion TLS via HTTPS en el puerto 443 fallaba con errores curl: (35) Send failure: Broken pipe.

## Diagnostico y Causa Raiz
1. Desalineacion de Rutas en Compose: El volumen de Nginx apuntaba a un directorio creado accidentalmente en lugar de montar el archivo default.conf.
2. Ausencia de Material Criptografico: Nginx abortaba la inicializacion del socket SSL al no encontrar /etc/nginx/ssl/server.crt.

## Decisiones Adoptadas
1. Estandarizacion de Rutas Relativas: Definir rutas relativas strictly en docker-compose.yml referenciadas desde el directorio de orquestacion.
2. Ciclo de Certificacion Local: Despliegue de certificados X.509 autofirmados (RSA 2048) y forzado de TLSv1.3.

## Consecuencias
* Validacion exitosa de respuesta HTTP 200 OK en puerto 443.
* Eliminacion de dependencias volatiles mediante montajes :ro.
