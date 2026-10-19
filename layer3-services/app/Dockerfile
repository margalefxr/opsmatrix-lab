FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
# Si el repo se clonó con umask 077, app.py llega con permisos 600
# y el usuario nobody no lo puede leer. Lo dejo legible para todos.
RUN chmod 644 requirements.txt app.py

# No correr como root dentro del contenedor
USER nobody

# Que los print salgan al momento en docker logs
ENV PYTHONUNBUFFERED=1

EXPOSE 5000
CMD ["python", "app.py"]
