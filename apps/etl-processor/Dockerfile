FROM python:3.12-slim

WORKDIR /app

# Install security patches and runtime utilities
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends procps && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y pip

COPY . .

# Security: Non-root user with UID 1000
RUN useradd -u 1000 -m -s /bin/bash etluser && chown -R etluser /app
USER etluser

ENTRYPOINT ["python", "-m", "src.main"]
LABEL org.opencontainers.image.source=https://github.com/Fauxx/FireMonitoringSystem
