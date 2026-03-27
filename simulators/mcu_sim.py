#!/usr/bin/env python3
"""MQTT simulator for fire-monitoring devices.
Optimized for TUP Capstone Dev/Prod Infrastructure.
"""
import argparse
import json
import os
import random
import time
from datetime import datetime

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

import paho.mqtt.client as mqtt

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Publish simulated sensor data over MQTT")
    # Defaulting to 18830 to match your docker-compose-dev.yml mapping
    parser.add_argument("--host", default=os.getenv("MQTT_HOST", "localhost"), help="MQTT broker host")
    parser.add_argument("--port", type=int, default=int(os.getenv("MQTT_PORT", 18830)), help="MQTT broker port")
    # Aligning topic with Telegraf's fire/sensors/# wildcard
    parser.add_argument("--topic", default=os.getenv("MQTT_TOPIC", "fire/sensors/REYES_P"), help="MQTT topic")
    parser.add_argument("--interval", type=float, default=float(os.getenv("PUBLISH_INTERVAL", 5.0)), help="Seconds between publishes")
    parser.add_argument("--client-id", default=os.getenv("MQTT_CLIENT_ID", "mcu-sim-k1"), help="MQTT client ID")
    parser.add_argument("--h-id", default=os.getenv("H_ID", "REYES_P"), help="Household ID")
    parser.add_argument("--d-id", default=os.getenv("D_ID", "K1"), help="Device ID")
    parser.add_argument("--pos", default=os.getenv("POS", "Kitchen"), help="Position")
    return parser

def generate_payload(args: argparse.Namespace) -> dict:
    """Generates the specific nested JSON structure required by Telegraf json_v2."""
    return {
        "h_id": args.h_id,
        "d_id": args.d_id,
        "pos": args.pos,
        "env": {
            # Randomizing within 'Normal' and 'Alert' ranges for demo purposes
            "t": round(random.uniform(24.0, 35.0), 1),
            "s": round(random.uniform(20.0, 150.0), 1),
        },
        "log": {
            "st": 1 # 1 = Active, 0 = Offline
        },
        # Fixed coordinates for the specific household
        "loc": [14.5995, 121.0365]
    }

def publish_loop(args: argparse.Namespace) -> None:
    # Use newer CallbackAPIVersion for compatibility with latest paho-mqtt
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2, client_id=args.client_id)

    try:
        client.connect(args.host, args.port, keepalive=60)
        print(f"🚀 Simulation Started!")
        print(f"📡 Broker: {args.host}:{args.port} | Topic: {args.topic}")

        while True:
            payload = generate_payload(args)
            client.publish(args.topic, json.dumps(payload))
            print(f"✅ [{datetime.now().strftime('%H:%M:%S')}] Sent: Temp {payload['env']['t']}°C, Smoke {payload['env']['s']}")
            time.sleep(args.interval)

    except ConnectionRefusedError:
        print(f"❌ Error: Could not connect to MQTT broker at {args.host}:{args.port}.")
        print("💡 Tip: Ensure your Docker containers are running (docker compose up mqtt).")
    except KeyboardInterrupt:
        print("\n🛑 Stopping simulator...")
    finally:
        client.disconnect()

if __name__ == "__main__":
    args = build_parser().parse_args()
    publish_loop(args)