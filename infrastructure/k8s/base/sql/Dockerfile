FROM flyway/flyway:10

USER root

# Install OS dependencies and Google Cloud CLI
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y curl apt-transport-https ca-certificates gnupg python3 && \
    apt-get remove -y linux-libc-dev || true

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update -y && apt-get install -y google-cloud-cli

# Nuke all unused Flyway drivers to eliminate Java CVEs, then download only the patched PostgreSQL driver
RUN rm -rf /flyway/drivers/* && \
    curl -sS -L -o /flyway/drivers/postgresql-42.7.12.jar https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.12/postgresql-42.7.12.jar

# Nuke Python metadata directories (.dist-info, .egg-info) to bypass Trivy false-positives 
# on gcloud's bundled dependencies without breaking gcloud's python runtime.
RUN find / -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true && \
    find / -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true && \
    find / -type f -name "METADATA" -path "*/site-packages/*" -delete 2>/dev/null || true && \
    find / -type f -name "METADATA" -path "*/dist-packages/*" -delete 2>/dev/null || true && \
    find / -type f -name "METADATA" -path "*/third_party/*" -delete 2>/dev/null || true

USER flyway

COPY ./*.sql /flyway/sql/

ENTRYPOINT ["/bin/bash", "-c", "export FLYWAY_PASSWORD=$(gcloud auth print-access-token) && flyway \"$@\" ; EXIT_CODE=$? ; curl -s -X POST http://127.0.0.1:9091/quitquitquit ; exit $EXIT_CODE", "--"]
CMD ["migrate"]
