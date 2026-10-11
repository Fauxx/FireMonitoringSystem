# -------------------------------------------------------------
# Stage 1: Build binary wheels with compilation dependencies
# -------------------------------------------------------------
FROM python:3.12-alpine AS builder

WORKDIR /app
RUN apk add --no-cache build-base postgresql-dev gcc musl-dev python3-dev

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# -------------------------------------------------------------
# Stage 2: Minimal Production Runner (No compilers)
# -------------------------------------------------------------
FROM python:3.12-alpine AS runner

WORKDIR /app

# Upgrade packages and install runtime-only libraries
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache libpq procps

COPY --from=builder /app/wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY . .

# Security: Non-root user with UID 1000
RUN adduser -u 1000 -D etluser && chown -R etluser /app
USER etluser

ENTRYPOINT ["python", "-m", "src.main"]
LABEL org.opencontainers.image.source=https://github.com/Fauxx/FireMonitoringSystem
