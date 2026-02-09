FROM python:3.11-slim

WORKDIR /app

# Ensure output is unbuffered
ENV PYTHONUNBUFFERED=True
ENV PORT=${PORT:-8080}
ENV API_URI="${API_URI:-http://localhost}"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates/ templates/

# Run the web service on container startup.
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app
