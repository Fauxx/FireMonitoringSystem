FROM flyway/flyway:10

# Install Google Cloud CLI so we can fetch IAM tokens for passwordless auth!
USER root
RUN apt-get update -y && apt-get install -y curl apt-transport-https ca-certificates gnupg python3
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get update -y && apt-get install -y google-cloud-cli

# Copy our migration scripts
COPY ./*.sql /flyway/sql/

# Override the entrypoint to dynamically grab the OAuth token right before running!
# We pass -c because flyway expects command line args like 'migrate'
# After flyway finishes, we ping the proxy to shut down so the Kubernetes Job can complete!
ENTRYPOINT ["/bin/bash", "-c", "export FLYWAY_PASSWORD=$(gcloud auth print-access-token) && flyway \"$@\" ; EXIT_CODE=$? ; curl -s -X POST http://127.0.0.1:9091/quitquitquit ; exit $EXIT_CODE", "--"]
CMD ["migrate"]
