#!/usr/bin/env python3
"""MQTT simulator for fire-monitoring devices.
Publishes random sensor readings on an MQTT topic for local/dev testing.
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
    # dotenv is optional; if missing we just skip it.
    pass

import paho.mqtt.client as mqtt


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Publish simulated sensor data over MQTT")
    parser.add_argument("--host", default=os.getenv("MQTT_HOST", "localhost"), help="MQTT broker host")
    parser.add_argument("--port", type=int, default=int(os.getenv("MQTT_PORT", 1883)), help="MQTT broker port")
    parser.add_argument("--topic", default=os.getenv("MQTT_TOPIC", "fire/sensors"), help="MQTT topic to publish to")
    parser.add_argument("--interval", type=float, default=float(os.getenv("PUBLISH_INTERVAL", 5.0)), help="Seconds between publishes")
    parser.add_argument("--client-id", default=os.getenv("MQTT_CLIENT_ID", "mcu-sim"), help="MQTT client ID")
    parser.add_argument("--username", default=os.getenv("MQTT_USERNAME"), help="MQTT username (optional)")
    parser.add_argument("--password", default=os.getenv("MQTT_PASSWORD"), help="MQTT password (optional)")
    parser.add_argument("--h-id", default=os.getenv("H_ID", "REYES_P"), help="Household/host ID")
    parser.add_argument("--d-id", default=os.getenv("D_ID", "K1"), help="Device ID")
    parser.add_argument("--pos", default=os.getenv("POS", "Kitchen"), help="Device position")
    parser.add_argument("--lat", type=float, default=float(os.getenv("LAT", 14.5995)), help="Latitude")
    parser.add_argument("--lon", type=float, default=float(os.getenv("LON", 121.0365)), help="Longitude")
    return parser


def connect_client(args: argparse.Namespace) -> mqtt.Client:
    client = mqtt.Client(client_id=args.client_id, clean_session=True)
    if args.username:
        client.username_pw_set(args.username, args.password)

    client.connect(args.host, args.port, keepalive=60)
    return client


def generate_payload() -> dict:
    return {
        "device_id": "sim-esp32",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "temperature": round(random.uniform(20, 80), 2),
        "smoke": round(random.uniform(0, 1), 3),
        "flame": round(random.uniform(0, 1), 3),
    }


def main():
    parser = build_parser()
    args = parser.parse_args()

    client = connect_client(args)
    print(f"Connected to MQTT broker at {args.host}:{args.port}, publishing to topic '{args.topic}'")

    try:
        while True:
            payload = {
                "h_id": args.h_id,
                "d_id": args.d_id,
                "pos": args.pos,
                "env": {
                    "t": round(random.uniform(25, 60), 1),
                    "s": round(random.uniform(50, 200), 1)
                },
                "log": {
                    "st": random.choice([0, 1])
                },
                "loc": [round(args.lat, 6), round(args.lon, 6)]
            }
            client.publish(args.topic, json.dumps(payload), qos=0, retain=False)
            print(f"Published: {payload}")
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("Stopping simulator...")
    finally:
        client.disconnect()


if __name__ == "__main__":
    main()
