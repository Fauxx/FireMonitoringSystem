FROM flyway/flyway:10

USER root

# Install OS dependencies and Google Cloud CLI
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y curl apt-transport-https ca-certificates gnupg python3 python3-pip && \
    apt-get remove -y linux-libc-dev || true

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update -y && apt-get install -y google-cloud-cli

# Force remove the OS-provided vulnerable python cryptography
RUN apt-get remove -y python3-cryptography || true

# Upgrade pip, install patched cryptography, then REMOVE pip and setuptools to kill msgpack/setuptools CVEs
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir cryptography==50.0.0 && \
    pip3 uninstall -y pip setuptools wheel

# Clean up Flyway vulnerable JDBC drivers
RUN find /flyway -name "databricks-jdbc*.jar" -delete && \
    find /flyway -name "netty-handler*.jar" -delete && \
    rm -f /flyway/drivers/postgresql-*.jar && \
    curl -sS -L -o /flyway/drivers/postgresql-42.7.12.jar https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.12/postgresql-42.7.12.jar

USER flyway

COPY ./*.sql /flyway/sql/

ENTRYPOINT ["/bin/bash", "-c", "export FLYWAY_PASSWORD=$(gcloud auth print-access-token) && flyway \"$@\" ; EXIT_CODE=$? ; curl -s -X POST http://127.0.0.1:9091/quitquitquit ; exit $EXIT_CODE", "--"]
CMD ["migrate"]
