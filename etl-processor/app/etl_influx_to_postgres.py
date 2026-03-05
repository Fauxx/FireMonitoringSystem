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
# 1. Configuration
# -----------------------------
load_dotenv()

INFLUXDB_URL = os.getenv("INFLUXDB_URL")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET")
DATABASE_URL = os.getenv("DATABASE_URL")

AGG_WINDOW_MINUTES = 5
RETRY_COUNT = 3
RETRY_DELAY = 5
TIMEZONE = "Asia/Manila"

# Thresholds
ALERT_THRESHOLDS = {
    "smoke": {"orange": 92, "red": 200},
    "temp": {"orange": 35.2, "red": 40},
    "flame": {"orange": 1027, "red": 1050}
}

# -----------------------------
# 2. Database Helpers
# -----------------------------
def connect_db():
    return psycopg2.connect(DATABASE_URL)

def get_last_timestamp(table_name="sensor_data_aggregated"):
    try:
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute(f"SELECT MAX(created_at) FROM {table_name};")
                ts = cur.fetchone()[0]
                if ts:
                    ts = pd.Timestamp(ts)
                    return ts.tz_convert(TIMEZONE) if ts.tzinfo else ts.tz_localize(TIMEZONE)
    except Exception:
        pass 
    return None

def get_alerts_today_count():
    try:
        with connect_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM incident_alerts WHERE started_at >= CURRENT_DATE;")
                return cur.fetchone()[0]
    except Exception:
        return 0

def upsert_table(df, table_name, conflict_cols):
    if df is None or df.empty: return

    df.columns = [c.lower() for c in df.columns]
    
    allowed_cols = [
        "time", "m", "host", "alert_level", "event_stage",
        "fa", "fb", "ga", "gb", "sa", "sb", "ta", "tb",
        "ks", "ls", "k", "l", "la", "lo", "a", "o",
        "timestamp_window", "readings_count", "created_at",
        "active_devices", "alerts_today", "system_uptime", "total_locations", "timestamp",
        "status_level" 
    ]
    valid_cols = [col for col in df.columns if col in allowed_cols]
    df_filtered = df[valid_cols]
    
    columns = list(df_filtered.columns)
    records = df_filtered.to_dict("records")
    values = [[rec.get(c) for c in columns] for rec in records]
    
    if not values: return

    if conflict_cols:
        conflict_cols_str = ", ".join(conflict_cols)
        update_str = ", ".join([f"{col}=EXCLUDED.{col}" for col in columns if col not in conflict_cols])
        query = f"""
            INSERT INTO {table_name} ({", ".join(columns)}) VALUES %s
            ON CONFLICT ({conflict_cols_str}) DO UPDATE SET {update_str}
        """
    else:
        query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES %s"

    try:
        with connect_db() as conn:
            with conn.cursor() as cur:
                execute_values(cur, query, values)
            conn.commit()
        
        if table_name == "sensor_data_aggregated":
            sample_dev = records[0].get('m', 'Unknown')
            logger.success(f"📊 AGGREGATION: Processed {len(values)} windows. (Sample: {sample_dev})")
        elif table_name == "system_metrics":
            active = records[0].get('active_devices', 0)
            alerts = records[0].get('alerts_today', 0)
            status = records[0].get('status_level', 1)
            logger.info(f"📈 METRICS: Active: {active} | Alerts: {alerts} | Status Lvl: {status}")
        else:
            logger.info(f"✅ DB WRITE: Upserted {len(values)} rows into {table_name}")
            
    except Exception as e:
        logger.error(f"Failed to write to {table_name}: {e}")

# -----------------------------
# 3. InfluxDB Extraction
# -----------------------------
def fetch_influx_data(last_ts=None):
    attempt = 0
    while attempt < RETRY_COUNT:
        try:
            client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG, timeout=60000)
            query_api = client.query_api()

            # --- GAP HANDLING ---
            if last_ts:
                last_ts_utc = (last_ts - pd.Timedelta(seconds=1)).tz_convert("UTC")
                start_time = last_ts_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
                logger.info(f"Fetching Influx data since: {start_time}")
            else:
                start_time = '-10m' 
                logger.info(f"Fetching Influx data (Start: {start_time})...")
            
            flux_query = f'''
            from(bucket:"{INFLUXDB_BUCKET}")
            |> range(start: {start_time})
            |> filter(fn: (r) => r["_measurement"] == "fire_data")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            '''

            result = query_api.query_data_frame(flux_query)
            if isinstance(result, list):
                result = pd.concat(result, ignore_index=True) if result else pd.DataFrame()

            if result.empty: return None

            result["_time"] = pd.to_datetime(result["_time"], utc=True).dt.tz_convert(TIMEZONE)
            result.rename(columns={"_time": "time"}, inplace=True)
            result.columns = [col.lower() for col in result.columns]

            if "m" in result.columns:
                result = result.dropna(subset=["m"])
                result["m"] = result["m"].astype(str)
            else:
                logger.warning("No 'm' column found in Influx Data. Skipping batch.")
                return None

            for col in ["sa", "sb", "ta", "tb", "fa", "fb", "ks", "ls"]:
                if col not in result.columns: result[col] = 0.0
                else: result[col] = pd.to_numeric(result[col], errors='coerce').fillna(0)

            return result

        except Exception as e:
            attempt += 1
            logger.error(f"Influx Error {attempt}: {e}")
            time.sleep(RETRY_DELAY)
    return None

# -----------------------------
# 4. Alert Logic
# -----------------------------
def compute_alerts(df):
    df = df.copy()
    alert_levels = []
    event_stages = []

    for _, row in df.iterrows():
        smoke = max(row.get("sa", 0), row.get("sb", 0))
        temp = max(row.get("ta", 0), row.get("tb", 0))
        flame = max(row.get("fa", 0), row.get("fb", 0))
        
        sensor_level = 1
        if (smoke >= ALERT_THRESHOLDS["smoke"]["red"] or 
            temp >= ALERT_THRESHOLDS["temp"]["red"] or 
            flame >= ALERT_THRESHOLDS["flame"]["red"]):
            sensor_level = 3
        elif (smoke >= ALERT_THRESHOLDS["smoke"]["orange"] or 
             (temp >= ALERT_THRESHOLDS["temp"]["orange"] and flame >= ALERT_THRESHOLDS["flame"]["orange"])):
            sensor_level = 2

        ks = int(row.get("ks", 0))
        ls = int(row.get("ls", 0))
        
        status_level = 1
        if ks == 3 or ls == 3: status_level = 3
        elif ks == 2 or ls == 2: status_level = 2
            
        final_level = max(sensor_level, status_level)
        alert_levels.append(final_level)
        
        if final_level == 3: event_stages.append("confirmed")
        elif final_level == 2: event_stages.append("orange")
        else: event_stages.append("green")

    return pd.DataFrame({"alert_level": alert_levels, "event_stage": event_stages})

# -----------------------------
# 5. Incident Logic (FIXED)
# -----------------------------
def process_incident_logic(df):
    if df is None or df.empty: return

    df = df.sort_values("time")
    SCENARIO_TIMEOUT_MINUTES = 8 
    
    new_incidents = 0
    updated_incidents = 0

    with connect_db() as conn:
        with conn.cursor() as cur:
            for _, row in df.iterrows():
                device = row['m']
                level = int(row['alert_level']) 
                curr_time = row['time']
                
                # CAST TO INT/FLOAT to match Schema
                vals = {
                    'sa': row.get('sa', 0), 'sb': row.get('sb', 0),
                    'ta': row.get('ta', 0), 'tb': row.get('tb', 0),
                    'fa': row.get('fa', 0), 'fb': row.get('fb', 0),
                    'ks': int(row.get('ks', 0)), 'ls': int(row.get('ls', 0)),
                    'k': int(row.get('k', 0)),   'l': int(row.get('l', 0))
                }

                # 1. UPDATE EXISTING (Sessionize)
                # Logic: Find ANY active fire on this device (regardless of current level). 
                # If found, extend the time and upgrade the severity if needed.
                update_query = f"""
                    UPDATE incident_alerts
                    SET last_seen = %s, 
                        updated_at = NOW(),
                        alert_level = GREATEST(alert_level, %s), -- Upgrade Status if needed
                        sa=GREATEST(sa, %s), sb=GREATEST(sb, %s), -- Keep Peak Readings
                        ta=GREATEST(ta, %s), tb=GREATEST(tb, %s), 
                        fa=GREATEST(fa, %s), fb=GREATEST(fb, %s),
                        ks=%s, ls=%s, k=%s, l=%s
                    WHERE m = %s 
                      AND last_seen > %s - INTERVAL '{SCENARIO_TIMEOUT_MINUTES} minutes'
                    RETURNING m;
                """
                
                cur.execute(update_query, (
                    curr_time, 
                    level, # Comparison for GREATEST
                    vals['sa'], vals['sb'], vals['ta'], vals['tb'], vals['fa'], vals['fb'], 
                    vals['ks'], vals['ls'], vals['k'], vals['l'],
                    device, 
                    curr_time # For the Timeout Calculation
                ))
                updated = cur.fetchone()

                # 2. INSERT NEW (Only if no active session exists)
                if not updated:
                    logger.warning(f"🔥 INCIDENT [NEW]: Device {device} | Level {level} | Time: {curr_time.strftime('%H:%M:%S')}")
                    new_incidents += 1
                    
                    insert_query = """
                        INSERT INTO incident_alerts (
                            time, m, alert_level, started_at, last_seen, updated_at,
                            sa, sb, ta, tb, fa, fb, ks, ls, k, l,
                            event_stage, host, a, o
                        ) VALUES (%s, %s, %s, %s, %s, NOW(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """
                    cur.execute(insert_query, (
                        curr_time, device, level, curr_time, curr_time,
                        vals['sa'], vals['sb'], vals['ta'], vals['tb'], vals['fa'], vals['fb'], vals['ks'], vals['ls'], vals['k'], vals['l'],
                        row.get('event_stage'), row.get('host'), row.get('a'), row.get('o')
                    ))
                else:
                    # Log update (optional, keeps logs clean)
                    updated_incidents += 1

        conn.commit()
    
    if new_incidents > 0 or updated_incidents > 0:
        logger.success(f"🚨 INCIDENT SUMMARY: {new_incidents} New, {updated_incidents} Updated")

# -----------------------------
# 6. Aggregation
# -----------------------------
def aggregate_data(df):
    if df is None or df.empty: return None
    df = df.copy()
    df["timestamp_window"] = df["time"].dt.floor(f"{AGG_WINDOW_MINUTES}min")

    agg_map = {
        "fa": "mean", "fb": "mean", "sa": "mean", "sb": "mean", "ta": "mean", "tb": "mean",
        "ks": "max", "ls": "max", "k": "max", "l": "max",
        "alert_level": "max", "event_stage": "first", "host": "first", "a": "first", "o": "first"
    }
    valid_agg = {k: v for k, v in agg_map.items() if k in df.columns}
    
    df_agg = df.groupby(["m", "timestamp_window"], as_index=False).agg(valid_agg)
    df_agg["readings_count"] = df.groupby(["m", "timestamp_window"]).size().values
    df_agg["created_at"] = pd.Timestamp.now(tz=TIMEZONE)
    return df_agg

# -----------------------------
# 7. Main Execution
# -----------------------------
def main():
    logger.add("logs/etl.log", rotation="10 MB")
    print("\n--- STARTING ETL RUN ---")

    last_ts = get_last_timestamp()
    df_raw = fetch_influx_data(last_ts)
    
    # Initialize variables for metrics
    active_devices_count = 0
    total_locations_count = 0
    max_alert_level = 1 

    if df_raw is not None and not df_raw.empty:
        # A. Alerts
        alerts = compute_alerts(df_raw)
        df_raw["alert_level"] = alerts["alert_level"]
        df_raw["event_stage"] = alerts["event_stage"]
        
        # Calculate MAX Alert Level for this batch
        if not df_raw.empty:
            max_alert_level = df_raw["alert_level"].max()

        incident_rows = df_raw[df_raw["alert_level"] >= 2].copy()
        if not incident_rows.empty:
            process_incident_logic(incident_rows)
        else:
            logger.info("No active incidents in this batch.")

        # B. Aggregation
        df_agg = aggregate_data(df_raw)
        upsert_table(df_agg, "sensor_data_aggregated", conflict_cols=["m", "timestamp_window"])
        
        # C. Real Metrics
        active_devices_count = df_agg["m"].nunique()
        if "a" in df_agg.columns:
            total_locations_count = df_agg["a"].nunique()

    else:
        logger.info("No new data found from InfluxDB.")

    # --- D. SYSTEM METRICS (HEARTBEAT) ---
    final_status = 1
    
    if active_devices_count == 0:
        final_status = 0 # Idle/Offline
    else:
        final_status = int(max_alert_level)

    total_alerts_today = get_alerts_today_count()
    
    metrics = pd.DataFrame([{
        "timestamp": pd.Timestamp.now(tz=TIMEZONE),
        "active_devices": active_devices_count, 
        "alerts_today": total_alerts_today, 
        "system_uptime": 100.0,
        "total_locations": total_locations_count,
        "status_level": final_status
    }])
    
    upsert_table(metrics, "system_metrics", conflict_cols=None)

    print("--- ETL RUN FINISHED ---\n")

if __name__ == "__main__":
    main()