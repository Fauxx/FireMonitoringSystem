import os
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timedelta
from loguru import logger
from influxdb_client import InfluxDBClient
from dotenv import load_dotenv

# -----------------------------
# 1. Configuration (Environment Driven)
# -----------------------------
load_dotenv()

INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://influx:8086")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG", "fire-monitoring")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET", "sensor-data")
INFLUX_MEASUREMENT = os.getenv("INFLUX_MEASUREMENT", "node_telemetry")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://fireuser:changeme@db:5432/fire_monitoring")

ETL_SYNC_INTERVAL = int(os.getenv("ETL_SYNC_INTERVAL", 10))
AGG_WINDOW_MINUTES = int(os.getenv("AGG_WINDOW_MINUTES", 5))
DEFAULT_RANGE = os.getenv("INFLUX_DEFAULT_RANGE", "-24h")

# Optimized 3NF Columns (Removed lat, lon, raw_payload)
ALLOWED_COLS = ["h_id", "received_at", "status", "temp_c", "smoke_ppm", "flame_intensity"]

_db_conn = None

def get_db_conn():
    global _db_conn
    if _db_conn is None or _db_conn.closed != 0:
        _db_conn = psycopg2.connect(DATABASE_URL)
    return _db_conn

# -----------------------------
# 2. Data Extraction
# -----------------------------
def fetch_influx_data(last_ts=None):
    try:
        if not INFLUXDB_TOKEN: return pd.DataFrame()
        client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
        query_api = client.query_api()

        if last_ts is not None:
            ts_str = (last_ts + timedelta(milliseconds=1)).isoformat()
            if not ts_str.endswith("Z") and "+" not in ts_str: ts_str += "Z"
            range_clause = f"|> range(start: time(v: \"{ts_str}\"))"
        else:
            range_clause = f"|> range(start: {DEFAULT_RANGE})"

        flux = f"""
from(bucket: "{INFLUXDB_BUCKET}")
  {range_clause}
  |> filter(fn: (r) => r._measurement == "{INFLUX_MEASUREMENT}")
  |> pivot(rowKey:["_time", "device_id"], columnKey:["_field"], valueColumn:"_value")
  |> keep(columns: ["_time", "device_id", "status_code", "temperature_c", "smoke_ppm", "flame_intensity"])
"""
        df = query_api.query_data_frame(org=INFLUXDB_ORG, query=flux)
        if isinstance(df, list): df = pd.concat(df) if df else pd.DataFrame()
        if df is None or df.empty: return pd.DataFrame()

        df.rename(columns={
            "_time": "received_at", 
            "device_id": "h_id", 
            "status_code": "status",
            "temperature_c": "temp_c",
            "smoke_ppm": "smoke_ppm",
            "flame_intensity": "flame_intensity"
        }, inplace=True)
        
        df["received_at"] = pd.to_datetime(df["received_at"], errors="coerce")
        return df
    except Exception as e:
        logger.error(f"❌ Influx fetch failed: {e}")
        return pd.DataFrame()

# -----------------------------
# 3. Processing & Transformation (KPIs)
# -----------------------------
def process_telemetry_batch(df_raw):
    if df_raw is None or df_raw.empty:
        return pd.DataFrame(), pd.DataFrame()

    df = df_raw.copy()
    df["status"] = pd.to_numeric(df.get("status"), errors="coerce").fillna(0).astype(int)
    
    events_to_save = []
    incidents_to_create = []

    df["interval_time"] = df["received_at"].dt.floor(f"{AGG_WINDOW_MINUTES}min")

    for h_id, group in df.groupby("h_id"):
        anomalies = group[group["status"].isin([1, 2])]
        normals = group[group["status"] == 0]

        if not anomalies.empty:
            batch_count = len(anomalies)
            batch_temp_avg = float(anomalies['temp_c'].mean())
            batch_smoke_avg = float(anomalies['smoke_ppm'].mean())
            batch_flame_avg = float(anomalies['flame_intensity'].mean())
            max_status = int(anomalies['status'].max())
            last_seen = anomalies['received_at'].max()
            started_at = anomalies['received_at'].min()

            try:
                conn = get_db_conn()
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT id FROM historical_fire_incidents WHERE h_id = %s AND is_active = TRUE AND last_seen_at > NOW() - INTERVAL '30 minutes' LIMIT 1",
                        (h_id,)
                    )
                    active_session = cur.fetchone()

                    if active_session:
                        cur.execute("""
                            UPDATE historical_fire_incidents 
                            SET last_seen_at = GREATEST(last_seen_at, %s),
                                max_alert_level = GREATEST(max_alert_level, %s),
                                avg_temperature_c = ROUND(((avg_temperature_c * readings_count) + (%s * %s)) / (readings_count + %s), 2),
                                avg_smoke_ppm = ROUND(((avg_smoke_ppm * readings_count) + (%s * %s)) / (readings_count + %s), 2),
                                avg_flame_intensity = ROUND(((avg_flame_intensity * readings_count) + (%s * %s)) / (readings_count + %s), 2),
                                readings_count = readings_count + %s
                            WHERE id = %s
                        """, (
                            last_seen, max_status,
                            batch_temp_avg, batch_count, batch_count,
                            batch_smoke_avg, batch_count, batch_count,
                            batch_flame_avg, batch_count, batch_count,
                            batch_count, active_session[0]
                        ))
                        conn.commit()
                    else:
                        incidents_to_create.append({
                            "h_id": h_id,
                            "started_at": started_at,
                            "last_seen_at": last_seen,
                            "max_alert_level": max_status,
                            "is_active": True,
                            "avg_temperature_c": round(batch_temp_avg, 2),
                            "avg_smoke_ppm": round(batch_smoke_avg, 2),
                            "avg_flame_intensity": round(batch_flame_avg, 2),
                            "readings_count": batch_count
                        })
                        
            except Exception as e:
                logger.error(f"❌ Anomaly handling failed for {h_id}: {e}")

            top_anomaly = anomalies.sort_values("status", ascending=False).iloc[0]
            events_to_save.append(top_anomaly)

        if not normals.empty:
            if not anomalies.empty:
                latest_anomaly_ts = anomalies["received_at"].max()
                latest_normal_ts = normals["received_at"].max()
                if latest_normal_ts > latest_anomaly_ts:
                    try:
                        conn = get_db_conn()
                        with conn.cursor() as cur:
                            cur.execute(
                                "UPDATE historical_fire_incidents SET is_active = FALSE, last_seen_at = %s WHERE h_id = %s AND is_active = TRUE",
                                (latest_normal_ts, h_id)
                            )
                            conn.commit()
                    except Exception as e:
                        pass
            
            for interval, int_group in normals.groupby("interval_time"):
                row = int_group.iloc[0].copy()
                row["received_at"] = interval
                events_to_save.append(row)

    final_events = []
    for r in events_to_save:
        final_events.append({
            "h_id": r["h_id"],
            "status": int(r["status"]),
            "temp_c": float(r["temp_c"]) if pd.notnull(r.get("temp_c")) else None,
            "smoke_ppm": float(r["smoke_ppm"]) if pd.notnull(r.get("smoke_ppm")) else None,
            "flame_intensity": float(r["flame_intensity"]) if pd.notnull(r.get("flame_intensity")) else None,
            "received_at": r["received_at"]
        })

    return pd.DataFrame(final_events), pd.DataFrame(incidents_to_create)

def upsert_table(df, table_name, conflict_cols):
    if df is None or df.empty: return
    try:
        conn = get_db_conn()
        df_filtered = df[[col for col in df.columns if col in ALLOWED_COLS or table_name != "final_sensor_events"]]

        columns = list(df_filtered.columns)
        values = [[rec.get(c) for c in columns] for rec in df_filtered.to_dict("records")]

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

# -----------------------------
# 4. Main Execution
# -----------------------------
def run_main(last_ts=None):
    logger.info("🔄 Starting ETL Sync Batch...")

    df_raw = fetch_influx_data(last_ts)

    if df_raw is None or df_raw.empty:
        logger.info("😴 No new data to process.")
        return last_ts

    df_events, df_incidents = process_telemetry_batch(df_raw)

    if not df_events.empty:
        upsert_table(df_events, "final_sensor_events", conflict_cols=None)
    if not df_incidents.empty:
        upsert_table(df_incidents, "historical_fire_incidents", conflict_cols=None)

    new_cursor = df_raw["received_at"].max()
    logger.success("✨ Batch synchronization successful.")
    return new_cursor

if __name__ == "__main__":
    os.makedirs("logs", exist_ok=True)
    logger.add("logs/etl.log", rotation="10 MB", level="INFO")
    logger.info(f"🚀 ETL Service Started. Sync Interval: {ETL_SYNC_INTERVAL}s")

    cursor = None
    while True:
        try:
            cursor = run_main(cursor)
        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.critical(f"💥 Unexpected Service Error: {e}")
        time.sleep(ETL_SYNC_INTERVAL)
