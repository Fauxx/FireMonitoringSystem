import os
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values, Json
from datetime import datetime, timedelta
from loguru import logger
from influxdb_client import InfluxDBClient
from dotenv import load_dotenv

# -----------------------------
# 1. Configuration (Environment Driven)
# -----------------------------
load_dotenv()

# Connectivity (defaults line up with docker-compose service names)
INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://influx:8086")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG", "fire-monitoring")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET", "sensor-data")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://fireuser:changeme@db:5432/fire_monitoring")

# Timing & Service Logic
ETL_SYNC_INTERVAL = int(os.getenv("ETL_SYNC_INTERVAL", 60)) # Seconds between runs
AGG_WINDOW_MINUTES = int(os.getenv("AGG_WINDOW_MINUTES", 5))
TIMEZONE = os.getenv("TZ", "Asia/Manila")
DEFAULT_RANGE = os.getenv("INFLUX_DEFAULT_RANGE", "-2d")

# Thresholds (Configurable via .env)
ALERT_THRESHOLDS = {
    "smoke": {
        "orange": float(os.getenv("THRESHOLD_SMOKE_ORANGE", 92)),
        "red": float(os.getenv("THRESHOLD_SMOKE_RED", 200))
    },
    "temp": {
        "orange": float(os.getenv("THRESHOLD_TEMP_ORANGE", 35.2)),
        "red": float(os.getenv("THRESHOLD_TEMP_RED", 40))
    },
    "flame": {
        "orange": float(os.getenv("THRESHOLD_FLAME_ORANGE", 1027)),
        "red": float(os.getenv("THRESHOLD_FLAME_RED", 1050))
    }
}

ALLOWED_COLS = [
    "time", "m", "host", "alert_level", "event_stage",
    "fa", "fb", "ga", "gb", "sa", "sb", "ta", "tb",
    "ks", "ls", "k", "l", "la", "lo", "a", "o",
    "timestamp_window", "readings_count", "created_at",
    "active_devices", "alerts_today", "system_uptime", "total_locations", "timestamp",
    "status_level", "h_id", "d_id", "pos", "temp_c", "smoke_ppm", "status", "lat", "lon", "raw_payload", "received_at"
]

# -----------------------------
# 2. Global Database Connection
# -----------------------------
# In Production, we keep one connection open to avoid TCP overhead
_db_conn = None

def get_db_conn():
    global _db_conn
    if _db_conn is None or _db_conn.closed != 0:
        logger.info("🔌 Establishing new PostgreSQL connection...")
        _db_conn = psycopg2.connect(DATABASE_URL)
    return _db_conn

# -----------------------------
# 3. Helpers & Logic
# -----------------------------

def fetch_influx_data(last_ts=None):
    """Placeholder fetch; returns empty frame until real query logic is restored."""
    logger.warning("fetch_influx_data is not implemented; returning empty dataset")
    return pd.DataFrame(columns=ALLOWED_COLS)


def compute_alerts(df):
    """Placeholder alert computation keeping pipeline alive."""
    if df is None or df.empty:
        return {"alert_level": [], "event_stage": []}

    # Default every record to green/normal until logic is reintroduced
    return {
        "alert_level": ["green"] * len(df),
        "event_stage": ["normal"] * len(df),
    }

def upsert_table(df, table_name, conflict_cols):
    if df is None or df.empty: return
    try:
        conn = get_db_conn()
        df.columns = [c.lower() for c in df.columns]
        valid_cols = [col for col in df.columns if col in ALLOWED_COLS]
        df_filtered = df[valid_cols]

        columns = list(df_filtered.columns)
        records = df_filtered.to_dict("records")
        values = [[rec.get(c) for c in columns] for rec in records]

        if not values: return

        if conflict_cols:
            conflict_cols_str = ", ".join(conflict_cols)
            update_str = ", ".join([f"{col}=EXCLUDED.{col}" for col in columns if col not in conflict_cols])
            query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES %s ON CONFLICT ({conflict_cols_str}) DO UPDATE SET {update_str}"
        else:
            query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES %s"

        with conn.cursor() as cur:
            execute_values(cur, query, values)
        conn.commit()
        logger.info(f"✅ DB WRITE: {len(values)} rows to {table_name}")
    except Exception as e:
        logger.error(f"❌ Failed to write to {table_name}: {e}")
        if _db_conn: _db_conn.rollback()

# [Include your process_incident_logic, aggregate_data, etc.]

# -----------------------------
# 4. Main Execution
# -----------------------------
def run_main():
    logger.info("🔄 Starting ETL Sync Batch...")

    last_ts = None # Or call your get_last_timestamp() logic
    df_raw = fetch_influx_data(last_ts)

    if df_raw is not None and not df_raw.empty:
        # Processing steps...
        alerts = compute_alerts(df_raw)
        df_raw["alert_level"] = alerts["alert_level"]
        df_raw["event_stage"] = alerts["event_stage"]

        # Upsert etc...
        logger.success("✨ Batch synchronization successful.")
    else:
        logger.info("😴 No new data to process.")

if __name__ == "__main__":
    os.makedirs("logs", exist_ok=True)
    logger.add("logs/etl.log", rotation="10 MB", level="INFO")
    logger.info(f"🚀 ETL Service Started. Sync Interval: {ETL_SYNC_INTERVAL}s")

    # THE SERVICE LOOP
    while True:
        try:
            run_main()
        except KeyboardInterrupt:
            logger.warning("🛑 ETL Service stopping (KeyboardInterrupt)")
            break
        except Exception as e:
            logger.critical(f"💥 Unexpected Service Error: {e}")

        time.sleep(ETL_SYNC_INTERVAL)