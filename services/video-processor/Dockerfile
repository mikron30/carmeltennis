FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN apt-get update \
    && apt-get install --no-install-recommends -y ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --uid 10001 videoapp

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER videoapp

EXPOSE 8080

# Cloud Run's request timeout must be configured to at least this value when
# deploying. Keep worker/thread concurrency at one for memory-heavy FFmpeg work.
CMD ["sh", "-c", "exec gunicorn --bind :${PORT} --workers 1 --threads 1 --timeout 900 --graceful-timeout 30 --access-logfile - --error-logfile - app.main:app"]
