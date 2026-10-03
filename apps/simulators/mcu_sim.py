#!/usr/bin/env python3
"""MQTT simulator for fire-monitoring devices.
Enterprise-Grade schema with UTC Timestamps and Skinny Payloads.
"""
import argparse
import json
import os
import random
import time
from datetime import datetime, timezone

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

import paho.mqtt.client as mqtt

# Global state to allow MQTT overrides
CURRENT_STATUS = None
IS_ACTIVE = True  # Allows turning the device on/off

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Publish simulated sensor data over MQTT")
    parser.add_argument("--host", default=os.getenv("MQTT_HOST", "localhost"), help="MQTT broker host")
    parser.add_argument("--port", type=int, default=int(os.getenv("MQTT_BROKER_PORT", 18830)), help="MQTT broker port")
    parser.add_argument("--interval", type=float, default=float(os.getenv("PUBLISH_INTERVAL", 5.0)), help="Seconds between publishes")
    parser.add_argument("--client-id", default=os.getenv("MQTT_CLIENT_ID", f"mcu-sim-{random.randint(1000,9999)}"), help="MQTT client ID")
    parser.add_argument("--device-id", default=os.getenv("DEVICE_ID", "FMS-V1-0001"), help="Standardized Device ID (e.g. FMS-V1-0001)")
    parser.add_argument("--status", type=int, choices=[0, 1, 2], default=None, help="Force a specific status (0=Normal, 1=Warning, 2=Critical)")
    parser.add_argument("--transport", default=os.getenv("MQTT_TRANSPORT", "tcp"), choices=["tcp", "websockets"])
    parser.add_argument("--ws-path", default=os.getenv("MQTT_WS_PATH", "/mqtt"))
    parser.add_argument("--insecure", action="store_true")
    return parser

def generate_payload(args: argparse.Namespace) -> dict:
    """Generates the Enterprise-Grade 'Skinny Payload' JSON structure."""
    global CURRENT_STATUS
    if CURRENT_STATUS is not None:
        status_code = CURRENT_STATUS
    else:
        # Simulate edge state machine: 85% normal, 12% warning, 3% critical
        status_code = random.choices([0, 1, 2], weights=[0.85, 0.12, 0.03])[0]

    if status_code == 0:
        temp = random.uniform(28.0, 32.0)
        smoke = random.uniform(10, 50)
        flame = 0.0
    elif status_code == 1:
        temp = random.uniform(33.0, 40.0)
        smoke = random.uniform(50, 150)
        flame = random.uniform(0.1, 0.4)
    else:
        temp = random.uniform(45.0, 70.0)
        smoke = random.uniform(200, 500)
        flame = random.uniform(0.8, 1.0)

    # ISO 8601 UTC Timestamp
    utc_now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    return {
        "device_id": args.device_id,
        "timestamp": utc_now,
        "status_code": status_code,
        "readings": {
            "temperature_c": round(temp, 2),
            "smoke_ppm": round(smoke, 2),
            "flame_intensity": round(flame, 2)
        }
    }

def on_message(client, userdata, msg):
    """Callback for when a command is received from the Dashboard/API"""
    global CURRENT_STATUS, IS_ACTIVE
    try:
        payload = json.loads(msg.payload.decode())
        
        # Power commands (on/off)
        if "power" in payload:
            if payload["power"].lower() == "on":
                IS_ACTIVE = True
                print(f"🟢 POWER ON received on {msg.topic}")
            elif payload["power"].lower() == "off":
                IS_ACTIVE = False
                print(f"🔴 POWER OFF received on {msg.topic}")
                
        # Status overrides (0, 1, 2)
        if "status_code" in payload:
            CURRENT_STATUS = int(payload["status_code"])
            print(f"⚠️ STATUS OVERRIDE received on {msg.topic}: Changing status to {CURRENT_STATUS}")
            
    except Exception as e:
        print(f"Error parsing control message: {e}")

def publish_loop(args: argparse.Namespace) -> None:
    global CURRENT_STATUS, IS_ACTIVE
    CURRENT_STATUS = args.status
    
    # Topic for telemetry
    telemetry_topic = f"fire/sensors/{args.device_id}"
    
    # Topics for control (Dashboard overrides)
    control_topic_specific = f"fire/control/{args.device_id}"
    control_topic_all = "fire/control/all"

    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2, client_id=args.client_id, transport=args.transport)
    client.on_message = on_message

    if args.transport == "websockets":
        client.ws_set_options(path=args.ws_path)

    if args.port == 443:
        if args.insecure:
            import ssl
            client.tls_set(cert_reqs=ssl.CERT_NONE)
            client.tls_insecure_set(True)
        else:
            client.tls_set()

    try:
        client.connect(args.host, args.port, keepalive=60)
        
        # Subscribe to BOTH specific device controls and the global "ALL" override
        client.subscribe([(control_topic_specific, 0), (control_topic_all, 0)])
        
        client.loop_start()
        print(f"🚀 Simulator [{args.device_id}] Started!")
        print(f"📡 Publishing to: {telemetry_topic}")
        print(f"🎧 Listening for commands on: {control_topic_specific} AND {control_topic_all}")

        while True:
            if not IS_ACTIVE:
                # If powered off, just wait and do nothing
                time.sleep(args.interval)
                continue
                
            payload = generate_payload(args)
            client.publish(telemetry_topic, json.dumps(payload))
            print(f"✅ [{datetime.now().strftime('%H:%M:%S')}] Sent: Status {payload['status_code']} | Temp: {payload['readings']['temperature_c']}°C")
            time.sleep(args.interval)

    except ConnectionRefusedError:
        print(f"❌ Error: Could not connect to MQTT broker at {args.host}:{args.port}.")
    except KeyboardInterrupt:
        print(f"\n🛑 Stopping simulator [{args.device_id}]...")
    finally:
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    args = build_parser().parse_args()
    publish_loop(args)