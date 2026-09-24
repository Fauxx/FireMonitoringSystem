FROM python:3.12-alpine

WORKDIR /app

# Upgrade Alpine packages to fix vulnerabilities
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
    build-base \
    postgresql-dev \
    gcc \
    musl-dev \
    python3-dev \
    procps

COPY requirements.txt ./

# Upgrade base python tools and install jaraco.context and msgpack to avoid CVEs
RUN pip install --no-cache-dir --upgrade pip setuptools wheel "jaraco.context>=6.1.0" "msgpack>=1.2.1" && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Security: Run as non-root user
RUN adduser -D etluser && chown -R etluser /app
USER etluser

# Healthcheck: Verify the python process is active
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -f "python -m src.main" || exit 1

ENTRYPOINT ["python", "-m", "src.main"]
