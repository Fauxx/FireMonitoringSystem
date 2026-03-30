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
INFLUX_MEASUREMENT = os.getenv("INFLUX_MEASUREMENT", "final_sensor_readings")
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
    """Fetch final sensor readings from Influx and pivot to a wide dataframe."""
    try:
        if not INFLUXDB_TOKEN:
            logger.warning("INFLUXDB_TOKEN missing; skipping fetch")
            return pd.DataFrame(columns=ALLOWED_COLS)

        client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
        query_api = client.query_api()

        # Pull the most recent window; optionally narrow using last_ts
        range_clause = f"|> range(start: {DEFAULT_RANGE})" if last_ts is None else f"|> range(start: time(v: {last_ts.isoformat()}))"

        # We assume tags h_id/d_id and fields: t (temp), s (smoke), st (status), pos, lat, lon.
        flux = f"""
from(bucket: \"{INFLUXDB_BUCKET}\")
  {range_clause}
  |> filter(fn: (r) => r._measurement == \"{INFLUX_MEASUREMENT}\")
  |> pivot(rowKey:[\"_time\", \"h_id\", \"d_id\"], columnKey:[\"_field\"], valueColumn:\"_value\")
  |> keep(columns: [\"_time\", \"h_id\", \"d_id\", \"pos\", \"t\", \"s\", \"st\", \"lat\", \"lon\"])
"""

        df = query_api.query_data_frame(org=INFLUXDB_ORG, query=flux)

        # query_data_frame may return a list-like; ensure a single DataFrame
        if isinstance(df, list):
            df = pd.concat(df) if df else pd.DataFrame()

        if df is None or df.empty:
            return pd.DataFrame(columns=ALLOWED_COLS)

        # Drop Influx internal columns if present
        df = df.loc[:, [c for c in df.columns if not c.startswith("_start") and not c.startswith("_stop") and c not in ["table"]]]
        df.rename(columns={"_time": "time", "t": "temp_c", "s": "smoke_ppm", "st": "status"}, inplace=True)
        df["received_at"] = pd.to_datetime(df["time"], errors="coerce")
        return df
    except Exception as e:
        logger.error(f"❌ Influx fetch failed: {e}")
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


def build_final_sensor_events(df):
    """Map wide dataframe to final_sensor_events columns."""
    if df is None or df.empty:
        return pd.DataFrame(columns=["h_id", "d_id", "pos", "temp_c", "smoke_ppm", "status", "lat", "lon", "raw_payload", "received_at"])

    # Ensure lat/lon numeric and keep raw payload for traceability
    df = df.copy()
    df["lat"] = pd.to_numeric(df.get("lat"), errors="coerce")
    df["lon"] = pd.to_numeric(df.get("lon"), errors="coerce")
    df["temp_c"] = pd.to_numeric(df.get("temp_c"), errors="coerce")
    df["smoke_ppm"] = pd.to_numeric(df.get("smoke_ppm"), errors="coerce")
    df["status"] = pd.to_numeric(df.get("status"), errors="coerce")

    def _row_payload(row):
        # Reconstruct the original-ish JSON shape
        loc = []
        if pd.notnull(row.get("lat")) and pd.notnull(row.get("lon")):
            loc = [float(row.get("lat")), float(row.get("lon"))]
        return {
            "h_id": row.get("h_id"),
            "d_id": row.get("d_id"),
            "pos": row.get("pos"),
            "env": {"t": row.get("temp_c"), "s": row.get("smoke_ppm")},
            "log": {"st": row.get("status")},
            "loc": loc,
            "time": row.get("time").isoformat() if isinstance(row.get("time"), pd.Timestamp) else row.get("time"),
        }

    final_df = pd.DataFrame({
        "h_id": df.get("h_id"),
        "d_id": df.get("d_id"),
        "pos": df.get("pos"),
        "temp_c": df.get("temp_c"),
        "smoke_ppm": df.get("smoke_ppm"),
        "status": df.get("status"),
        "lat": df.get("lat"),
        "lon": df.get("lon"),
        "raw_payload": df.apply(_row_payload, axis=1),
        "received_at": df.get("received_at")
    })

    final_df["raw_payload"] = final_df["raw_payload"].apply(Json)

    return final_df


def build_sensor_aggregates(df, window_minutes=5):
    """Lightweight aggregation to keep analytics endpoints usable."""
    if df is None or df.empty:
        return pd.DataFrame(columns=["m", "timestamp_window", "sa", "ta", "readings_count", "la", "lo", "host", "a", "o"])

    df = df.copy()
    df["timestamp_window"] = pd.to_datetime(df["received_at"], errors="coerce").dt.floor(f"{window_minutes}min")
    df["m"] = df.get("d_id")
    df["sa"] = df.get("smoke_ppm")
    df["ta"] = df.get("temp_c")
    df["la"] = df.get("lat")
    df["lo"] = df.get("lon")

    grouped = (
        df.groupby(["m", "timestamp_window"], dropna=False)
          .agg({
              "sa": "mean",
              "ta": "mean",
              "la": "mean",
              "lo": "mean",
              "pos": "first",
              "h_id": "first",
              "time": "count"
          })
          .rename(columns={"time": "readings_count"})
          .reset_index()
    )

    grouped.rename(columns={"pos": "host", "h_id": "a", "m": "m"}, inplace=True)
    # Retain optional text field
    grouped["o"] = None

    return grouped[["m", "timestamp_window", "sa", "ta", "readings_count", "la", "lo", "host", "a", "o"]]


def build_system_metrics(df):
    """Produce a single row for system_metrics from the latest batch."""
    if df is None or df.empty:
        return pd.DataFrame(columns=["timestamp", "active_devices", "alerts_today", "system_uptime", "total_locations", "status_level"])

    now = datetime.utcnow()
    active_devices = df["d_id"].nunique()
    total_locations = df["pos"].nunique() if "pos" in df.columns else active_devices

    metrics_df = pd.DataFrame([{
        "timestamp": now,
        "active_devices": int(active_devices),
        "alerts_today": 0,
        "system_uptime": 100.0,
        "total_locations": int(total_locations),
        "status_level": 1,
    }])
    return metrics_df

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

    last_ts = None # Placeholder for incremental cursor
    df_raw = fetch_influx_data(last_ts)

    if df_raw is None or df_raw.empty:
        logger.info("😴 No new data to process.")
        return

    # Lightweight alert scaffolding (kept for compatibility)
    alerts = compute_alerts(df_raw)
    df_raw["alert_level"] = alerts["alert_level"]
    df_raw["event_stage"] = alerts["event_stage"]

    # 1) Write final_sensor_events
    final_df = build_final_sensor_events(df_raw)
    upsert_table(final_df, "final_sensor_events", conflict_cols=None)

    # 2) Write sensor_data_aggregated (simplified)
    agg_df = build_sensor_aggregates(df_raw, window_minutes=AGG_WINDOW_MINUTES)
    upsert_table(agg_df, "sensor_data_aggregated", conflict_cols=["m", "timestamp_window"])

    # 3) Write system_metrics heartbeat
    metrics_df = build_system_metrics(df_raw)
    upsert_table(metrics_df, "system_metrics", conflict_cols=None)

    logger.success("✨ Batch synchronization successful.")

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