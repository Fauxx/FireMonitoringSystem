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
INFLUX_MEASUREMENT = os.getenv("INFLUX_MEASUREMENT", "fire_data")
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
    "status_level", "h_id", "status", "lat", "lon", "raw_payload", "received_at", "incident_timestamp"
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

        # Pivot by time and h_id tags
        flux = f"""
from(bucket: \"{INFLUXDB_BUCKET}\")
  {range_clause}
  |> filter(fn: (r) => r._measurement == \"{INFLUX_MEASUREMENT}\")
  |> pivot(rowKey:[\"_time\", \"h_id\"], columnKey:[\"_field\"], valueColumn:\"_value\")
  |> keep(columns: [\"_time\", \"h_id\", \"lat\", \"lon\", \"status\"])
"""

        df = query_api.query_data_frame(org=INFLUXDB_ORG, query=flux)

        if isinstance(df, list):
            df = pd.concat(df) if df else pd.DataFrame()

        if df is None or df.empty:
            return pd.DataFrame(columns=ALLOWED_COLS)

        df = df.loc[:, [c for c in df.columns if not c.startswith("_start") and not c.startswith("_stop") and c not in ["table"]]]
        df.rename(columns={"_time": "time"}, inplace=True)
        df["received_at"] = pd.to_datetime(df["time"], errors="coerce")
        return df
    except Exception as e:
        logger.error(f"❌ Influx fetch failed: {e}")
        return pd.DataFrame(columns=ALLOWED_COLS)


def process_telemetry_batch(df_raw):
    """
    Implements the core ETL logic for the status-based flat telemetry model:
    1. Deduplicate/aggregate historical points per h_id into a summarized row per interval (5m) for normal status (0).
    2. Anomaly Filter: Scan for status == 1 or status == 2.
    3. State Mutation: Bypass summarization thresholds upon anomaly detection (keep anomalies as separate individual records),
       and return events for final_sensor_events and incident_alerts.
    """
    if df_raw is None or df_raw.empty:
        return pd.DataFrame(), pd.DataFrame()

    df = df_raw.copy()
    df["status"] = pd.to_numeric(df.get("status"), errors="coerce").fillna(0).astype(int)
    df["lat"] = pd.to_numeric(df.get("lat"), errors="coerce")
    df["lon"] = pd.to_numeric(df.get("lon"), errors="coerce")

    normal_rows = []
    anomaly_rows = []
    incident_rows = []

    df["interval_time"] = df["received_at"].dt.floor(f"{AGG_WINDOW_MINUTES}min")

    for h_id, group in df.groupby("h_id"):
        anomalies = group[group["status"].isin([1, 2])]
        normals = group[group["status"] == 0]

        for _, row in anomalies.iterrows():
            anomaly_rows.append(row)
            if row["status"] == 2:
                incident_rows.append({
                    "h_id": h_id,
                    "lat": row["lat"],
                    "lon": row["lon"],
                    "status": row["status"],
                    "incident_timestamp": row["received_at"]
                })

        for interval, int_group in normals.groupby("interval_time"):
            if not int_group.empty:
                avg_lat = int_group["lat"].mean()
                avg_lon = int_group["lon"].mean()
                
                normal_rows.append({
                    "time": interval,
                    "received_at": interval,
                    "h_id": h_id,
                    "status": 0,
                    "lat": avg_lat,
                    "lon": avg_lon
                })

    final_events = []
    for r in normal_rows + anomaly_rows:
        raw_payload = {
            "h_id": r["h_id"],
            "lat": float(r["lat"]) if pd.notnull(r["lat"]) else None,
            "lon": float(r["lon"]) if pd.notnull(r["lon"]) else None,
            "status": int(r["status"]),
            "time": r["received_at"].isoformat() if isinstance(r["received_at"], pd.Timestamp) else str(r["received_at"])
        }
        final_events.append({
            "h_id": r["h_id"],
            "status": int(r["status"]),
            "lat": r["lat"],
            "lon": r["lon"],
            "raw_payload": Json(raw_payload),
            "received_at": r["received_at"]
        })

    df_events = pd.DataFrame(final_events)
    df_incidents = pd.DataFrame(incident_rows)

    return df_events, df_incidents

def build_sensor_aggregates(df, window_minutes=5):
    """Lightweight aggregation mapping h_id to m to keep analytics active."""
    if df is None or df.empty:
        return pd.DataFrame(columns=["m", "timestamp_window", "sa", "ta", "readings_count", "la", "lo", "host", "a", "o"])

    df = df.copy()
    df["timestamp_window"] = pd.to_datetime(df["received_at"], errors="coerce").dt.floor(f"{window_minutes}min")
    df["m"] = df.get("h_id")
    df["la"] = df.get("lat")
    df["lo"] = df.get("lon")

    grouped = (
        df.groupby(["m", "timestamp_window"], dropna=False)
          .agg({
              "la": "mean",
              "lo": "mean",
              "time": "count"
          })
          .rename(columns={"time": "readings_count"})
          .reset_index()
    )

    grouped["host"] = grouped["m"]
    grouped["a"] = grouped["m"]
    grouped["o"] = None
    grouped["sa"] = None
    grouped["ta"] = None

    return grouped[["m", "timestamp_window", "sa", "ta", "readings_count", "la", "lo", "host", "a", "o"]]

def build_system_metrics(df):
    """Produce system metrics heartbeat row."""
    if df is None or df.empty:
        return pd.DataFrame(columns=["timestamp", "active_devices", "alerts_today", "system_uptime", "total_locations", "status_level"])

    now = datetime.utcnow()
    active_devices = df["h_id"].nunique()
    total_locations = active_devices

    metrics_df = pd.DataFrame([{
        "timestamp": now,
        "active_devices": int(active_devices),
        "alerts_today": int((df["status"] == 2).sum()),
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

    # Process batch with deduplication and state mutation
    df_events, df_incidents = process_telemetry_batch(df_raw)

    # 1) Write final_sensor_events
    if df_events is not None and not df_events.empty:
        upsert_table(df_events, "final_sensor_events", conflict_cols=None)

    # 2) Write historical_fire_incidents registry table
    if df_incidents is not None and not df_incidents.empty:
        upsert_table(df_incidents, "historical_fire_incidents", conflict_cols=None)

    # 3) Write sensor_data_aggregated (simplified)
    agg_df = build_sensor_aggregates(df_raw, window_minutes=AGG_WINDOW_MINUTES)
    upsert_table(agg_df, "sensor_data_aggregated", conflict_cols=None)

    # 4) Write system_metrics heartbeat
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