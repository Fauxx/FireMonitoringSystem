import { useState, useEffect, useCallback } from 'react';
import mqtt from 'mqtt';
import type { SensorState, SensorTelemetry } from '../types';

export function useLiveSensors(initialSensors: Record<string, SensorState>) {
  const [sensors, setSensors] = useState<Record<string, SensorState>>({});
  const [activeAlert, setActiveAlert] = useState<SensorState | null>(null);
  const [mqttClient, setMqttClient] = useState<mqtt.MqttClient | null>(null);

  useEffect(() => {
    if (Object.keys(initialSensors).length > 0) {
      setSensors((prev) => ({ ...initialSensors, ...prev }));
    }
  }, [initialSensors]);

  useEffect(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const isLocal = window.location.hostname !== 'dev.fires.systems' && window.location.hostname !== 'fires.systems';
    const host = isLocal ? window.location.hostname + ':9001' : window.location.hostname + '/mqtt';
    
    const client = mqtt.connect(`${protocol}://${host}`, {
      clientId: `dash-v2-${Math.random().toString(16).slice(2)}`,
    });

    client.on('connect', () => {
      console.log('🔌 Connected to live MQTT stream');
      client.subscribe('fire/sensors/#');
      setMqttClient(client);
    });

    client.on('message', (_topic, message) => {
      try {
        const raw = JSON.parse(message.toString());
        // Handle both flattened ETL format (h_id, temp) and raw Simulator format (device_id, readings)
        const h_id = raw.h_id || raw.device_id;
        
        if (!h_id) return;
        
        const payload: SensorTelemetry = {
            h_id: h_id,
            lat: raw.lat, // May be missing in live stream, we preserve it below
            lon: raw.lon,
            status: raw.status ?? raw.status_code ?? 0,
            temp: raw.temp ?? raw.readings?.temperature_c,
            smoke: raw.smoke ?? raw.readings?.smoke_ppm,
            flame: raw.flame ?? raw.readings?.flame_intensity,
            _time: raw._time ?? raw.timestamp
        };

        setSensors((prev) => {
          // Preserve static properties (lat, lon, barangay) from initial DB load if missing in telemetry
          const existing = prev[h_id] || {};
          const newState = {
            ...prev,
            [h_id]: { 
                ...existing, 
                ...payload,
                // Ensure we don't overwrite valid coordinates with undefined
                lat: payload.lat ?? existing.lat,
                lon: payload.lon ?? existing.lon,
                lastUpdated: Date.now() 
            }
          };
          
          if (payload.status === 2 && prev[h_id]?.status !== 2) {
            setActiveAlert(newState[h_id]);
          }
          
          return newState;
        });
      } catch (err) {
        console.error("Failed to parse MQTT message", err);
      }
    });

    return () => {
      client.end();
    };
  }, []);

  const publishCommand = useCallback((h_id: string, command: any) => {
    if (mqttClient) {
      mqttClient.publish(`fire/control/${h_id}`, JSON.stringify(command));
    } else {
      console.warn("MQTT client not connected, cannot publish command");
    }
  }, [mqttClient]);

  return { sensors, activeAlert, clearAlert: () => setActiveAlert(null), publishCommand };
}
