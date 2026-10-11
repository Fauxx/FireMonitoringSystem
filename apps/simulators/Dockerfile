FROM python:3.12-slim

WORKDIR /app

# Security: Dedicated non-root user and group
RUN groupadd -r simgroup -g 1000 && useradd -r -u 1000 -g simgroup simuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=simuser:simgroup . .

USER simuser

ENTRYPOINT ["python3", "mcu_sim.py"]
LABEL org.opencontainers.image.source=https://github.com/Fauxx/FireMonitoringSystem
