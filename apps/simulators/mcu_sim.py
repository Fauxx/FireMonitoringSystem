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
    parser.add_argument("--status", type=int, choices=[0, 1, 2], default=None, help="Force a specific status (0=Normal, 1=Warning, 2=Critical)")
    parser.add_argument("--lat", type=float, default=14.5995, help="Latitude")
    parser.add_argument("--lon", type=float, default=121.0365, help="Longitude")
    parser.add_argument("--transport", default=os.getenv("MQTT_TRANSPORT", "tcp"), choices=["tcp", "websockets"], help="MQTT transport protocol (tcp or websockets)")
    parser.add_argument("--ws-path", default=os.getenv("MQTT_WS_PATH", "/mqtt"), help="WebSocket path (only for websockets transport)")
    parser.add_argument("--insecure", action="store_true", help="Bypass SSL certificate validation")
    return parser

def generate_payload(args: argparse.Namespace) -> dict:
    """Generates the flat JSON structure required by the new specification."""
    if args.status is not None:
        status = args.status
    else:
        # Simulate edge state machine: 85% normal, 12% warning, 3% critical
        status = random.choices([0, 1, 2], weights=[0.85, 0.12, 0.03])[0]

    return {
        "h_id": args.h_id,
        "lat": args.lat,
        "lon": args.lon,
        "status": status
    }

def publish_loop(args: argparse.Namespace) -> None:
    # Use newer CallbackAPIVersion for compatibility with latest paho-mqtt
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2, client_id=args.client_id, transport=args.transport)

    if args.transport == "websockets":
        client.ws_set_options(path=args.ws_path)

    # Automatically enable TLS if port is 443
    if args.port == 443:
        if args.insecure:
            import ssl
            client.tls_set(cert_reqs=ssl.CERT_NONE)
            client.tls_insecure_set(True)
        else:
            client.tls_set()

    try:
        client.connect(args.host, args.port, keepalive=60)
        client.loop_start()
        print(f"🚀 Simulation Started!")
        print(f"📡 Broker: {args.host}:{args.port} | Transport: {args.transport} | Topic: {args.topic}")

        while True:
            payload = generate_payload(args)
            client.publish(args.topic, json.dumps(payload))
            print(f"✅ [{datetime.now().strftime('%H:%M:%S')}] Sent: Status {payload['status']} (h_id: {payload['h_id']}, lat: {payload['lat']}, lon: {payload['lon']})")
            time.sleep(args.interval)

    except ConnectionRefusedError:
        print(f"❌ Error: Could not connect to MQTT broker at {args.host}:{args.port}.")
        print("💡 Tip: Ensure your Docker containers are running (docker compose up mqtt).")
    except KeyboardInterrupt:
        print("\n🛑 Stopping simulator...")
    finally:
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    args = build_parser().parse_args()
    publish_loop(args)