# OpsMatrix Lab - app del portal
# Cada visita se guarda en MariaDB y se muestra el total.
# Sirve para comprobar que Nginx -> app -> base de datos funciona.

import os
import pymysql
from flask import Flask, request

app = Flask(__name__)


def conectar():
    # Los datos de conexion vienen del docker-compose (que los lee de .env)
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
    )


@app.route("/")
def inicio():
    # IP real del cliente: la manda Nginx en la cabecera X-Real-IP
    ip_cliente = request.headers.get("X-Real-IP", request.remote_addr)
    protocolo = request.headers.get("X-Forwarded-Proto", "http")

    try:
        conexion = conectar()
        cursor = conexion.cursor()
        cursor.execute(
            "CREATE TABLE IF NOT EXISTS visitas ("
            "id INT AUTO_INCREMENT PRIMARY KEY, fecha DATETIME, ip VARCHAR(45))"
        )
        cursor.execute("INSERT INTO visitas (fecha, ip) VALUES (NOW(), %s)", (ip_cliente,))
        conexion.commit()
        cursor.execute("SELECT COUNT(*) FROM visitas")
        total = cursor.fetchone()[0]
        conexion.close()
    except Exception as e:
        print("Error con la base de datos:", e)
        return "<h1>Portal OpsMatrix</h1><p>Error conectando con la base de datos</p>", 500

    return (
        "<h1>Portal OpsMatrix</h1>"
        f"<p>Visitas guardadas en MariaDB: {total}</p>"
        f"<p>Has llegado por: {protocolo}</p>"
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
