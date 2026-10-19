FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

# No correr como root dentro del contenedor
USER nobody

# Que los print salgan al momento en docker logs
ENV PYTHONUNBUFFERED=1

EXPOSE 5000
CMD ["python", "app.py"]
