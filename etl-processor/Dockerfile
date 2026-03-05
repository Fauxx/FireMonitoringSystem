# Use Python 3.12 slim image
FROM python:3.12-slim

# Set working directory inside container
WORKDIR /app

# Copy all files from ETL repo into container
COPY . .

# Install dependencies
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Default command: run the ETL script
CMD ["python3", "etl_influx_to_postgres.py"]
