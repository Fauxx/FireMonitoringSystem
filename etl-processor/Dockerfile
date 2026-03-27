FROM python:3.11-slim

WORKDIR /app

# System deps for psycopg2 and basic tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    procps \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Security: Run as non-root user
RUN useradd -m etluser && chown -R etluser /app
USER etluser

# Healthcheck: Verify the python process is active
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -f "python3 -m src.main" || exit 1

ENTRYPOINT ["python3", "-m", "src.main"]
