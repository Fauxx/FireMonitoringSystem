import os
from dotenv import load_dotenv
from influxdb_client import InfluxDBClient
import psycopg2
from loguru import logger

# Load environment variables from .env
load_dotenv()

# ---- InfluxDB Configuration --------
INFLUXDB_URL = os.getenv("INFLUXDB_URL")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET")

# ---- PostgreSQL Configuration ----
DATABASE_URL = os.getenv("DATABASE_URL")

def test_influx_connection():
    """Check InfluxDB connection"""
    try:
        client = InfluxDBClient(
            url=INFLUXDB_URL,
            token=INFLUXDB_TOKEN,
            org=INFLUXDB_ORG
        )
        health = client.health()
        logger.info(f"✅ InfluxDB connection OK: {health.status}")
        client.close()
    except Exception as e:
        logger.error(f"❌ InfluxDB connection failed: {e}")

def test_postgres_connection():
    """Check PostgreSQL connection"""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        logger.info(f"✅ PostgreSQL connection OK: {version[0]}")
        cursor.close()
        conn.close()
    except Exception as e:
        logger.error(f"❌ PostgreSQL connection failed: {e}")

if __name__ == "__main__":
    os.makedirs("logs", exist_ok=True)
    logger.add("logs/etl.log", rotation="10 MB")
    logger.info("🔍 Testing ETL environment setup...")
    test_influx_connection()
    test_postgres_connection()
