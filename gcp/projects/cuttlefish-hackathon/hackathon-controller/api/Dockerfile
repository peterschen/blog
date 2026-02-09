FROM python:3.11-slim

WORKDIR /app

# Ensure output is unbuffered so that logs arrive instantly
ENV PYTHONUNBUFFERED=True
ENV PORT=${PORT:-8080}
ENV DB_NAME="${DB_NAME:-(default)}"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Run the web service on container startup. Cloud Run injects the PORT.
CMD exec uvicorn main:app --host 0.0.0.0 --port $PORT
