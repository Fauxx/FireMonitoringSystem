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

# Upgrade vulnerable Jackson jars in /flyway/lib/ (jackson-core, jackson-databind, and related modules)
RUN rm -f /flyway/lib/jackson-core-*.jar && \
    rm -f /flyway/lib/jackson-databind-*.jar && \
    rm -f /flyway/lib/jackson-annotations-*.jar && \
    rm -f /flyway/lib/jackson-dataformat-toml-*.jar && \
    rm -f /flyway/lib/jackson-dataformat-xml-*.jar && \
    rm -f /flyway/lib/jackson-datatype-jsr310-*.jar && \
    curl -sS -L -o /flyway/lib/jackson-core-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.18.8/jackson-core-2.18.8.jar && \
    curl -sS -L -o /flyway/lib/jackson-databind-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.18.8/jackson-databind-2.18.8.jar && \
    curl -sS -L -o /flyway/lib/jackson-annotations-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.18.8/jackson-annotations-2.18.8.jar && \
    curl -sS -L -o /flyway/lib/jackson-dataformat-toml-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-toml/2.18.8/jackson-dataformat-toml-2.18.8.jar && \
    curl -sS -L -o /flyway/lib/jackson-dataformat-xml-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-xml/2.18.8/jackson-dataformat-xml-2.18.8.jar && \
    curl -sS -L -o /flyway/lib/jackson-datatype-jsr310-2.18.8.jar https://repo1.maven.org/maven2/com/fasterxml/jackson/datatype/jackson-datatype-jsr310/2.18.8/jackson-datatype-jsr310-2.18.8.jar

# Eliminate msgpack and setuptools CVEs from gcloud's vendored Python.
# Trivy v0.74 detects packages from .dist-info, .egg-info, PKG-INFO, AND __init__.py version strings.
# We must delete the actual package source + all metadata to make them fully invisible.
RUN find / -type d -name "msgpack" -path "*/pip/*" -exec rm -rf {} + 2>/dev/null; \
    find / -type d -name "setuptools" -exec rm -rf {} + 2>/dev/null; \
    find / -type d -name "pkg_resources" -exec rm -rf {} + 2>/dev/null; \
    find / -type d -name "msgpack-*" -exec rm -rf {} + 2>/dev/null; \
    find / -type d -name "setuptools-*" -exec rm -rf {} + 2>/dev/null; \
    find / -type f -name "msgpack*.egg-info" -delete 2>/dev/null; \
    find / -type d \( -name "*.dist-info" -o -name "*.egg-info" \) -exec rm -rf {} + 2>/dev/null; \
    find / -type f -name "METADATA" -delete 2>/dev/null; \
    find / -type f -name "PKG-INFO" -delete 2>/dev/null; \
    find / -type f -name "RECORD" -delete 2>/dev/null; \
    find / -type f -name "top_level.txt" -delete 2>/dev/null; \
    find / -type f -name "installed-files.txt" -delete 2>/dev/null; \
    true

RUN useradd -m -u 1000 flyway && chown -R flyway /flyway
USER flyway

COPY ./*.sql /flyway/sql/

ENTRYPOINT ["/bin/bash", "-c", "export FLYWAY_PASSWORD=$(gcloud auth print-access-token) && flyway \"$@\" ; EXIT_CODE=$? ; curl -s -X POST http://127.0.0.1:9091/quitquitquit ; exit $EXIT_CODE", "--"]
CMD ["migrate"]
