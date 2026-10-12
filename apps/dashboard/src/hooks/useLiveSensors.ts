import { useState, useEffect, useCallback, useRef } from 'react';
import mqtt from 'mqtt';
import type { SensorState, SensorTelemetry } from '../types';

export function useLiveSensors(initialSensors: Record<string, SensorState>) {
  const [sensors, setSensors] = useState<Record<string, SensorState>>({});
  const [activeAlert, setActiveAlert] = useState<SensorState | null>(null);
  const [mqttClient, setMqttClient] = useState<mqtt.MqttClient | null>(null);

  // Keep a ref of known sensor metadata (coordinates) so incoming live MQTT payloads never drop coordinates
  const initialSensorsRef = useRef<Record<string, SensorState>>(initialSensors);
  useEffect(() => {
    initialSensorsRef.current = initialSensors;
  }, [initialSensors]);

  useEffect(() => {
    if (Object.keys(initialSensors).length > 0) {
      setSensors((prev) => {
        const merged = { ...prev };
        for (const [id, sensor] of Object.entries(initialSensors)) {
          const lat = sensor.lat != null && !isNaN(Number(sensor.lat)) ? Number(sensor.lat) : undefined;
          const lon = sensor.lon != null && !isNaN(Number(sensor.lon)) ? Number(sensor.lon) : undefined;

          if (!merged[id]) {
            merged[id] = { ...sensor, lat, lon };
          } else {
            // Keep live telemetry but ensure missing static DB fields (lat/lon) are preserved
            merged[id] = {
              ...merged[id],
              lat: merged[id].lat ?? lat,
              lon: merged[id].lon ?? lon,
            };
          }
        }
        return merged;
      });
    }
  }, [initialSensors]);

  // Track status outside of state to safely trigger alerts without React concurrency issues
  const statusRef = useRef<Record<string, number>>({});

  useEffect(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
    // Use /mqtt through ingress / proxy or direct websocket port if on local dev
    const isDevPort = window.location.port === '5173' || window.location.port === '3000';
    const host = isDevPort ? `${window.location.hostname}:9001` : `${window.location.host}/mqtt`;
    
    const client = mqtt.connect(`${protocol}://${host}`, {
      clientId: `dash-v2-${Math.random().toString(16).slice(2)}`,
    });

    client.on('connect', () => {
      console.log('🔌 Connected to live MQTT stream at', `${protocol}://${host}`);
      client.subscribe('fire/sensors/#');
      setMqttClient(client);
    });

    client.on('message', (_topic, message) => {
      try {
        const raw = JSON.parse(message.toString());
        const h_id: string = raw.h_id || raw.device_id;
        if (!h_id) return;
        
        const rawLat = raw.lat != null ? Number(raw.lat) : undefined;
        const rawLon = raw.lon != null ? Number(raw.lon) : undefined;

        const payload: SensorTelemetry = {
            h_id: h_id,
            lat: rawLat != null && !isNaN(rawLat) ? rawLat : undefined,
            lon: rawLon != null && !isNaN(rawLon) ? rawLon : undefined,
            status: raw.status ?? raw.status_code ?? 0,
            temp: raw.temp ?? raw.readings?.temperature_c,
            smoke: raw.smoke ?? raw.readings?.smoke_ppm,
            flame: raw.flame ?? raw.readings?.flame_intensity,
            _time: raw._time ?? raw.timestamp
        };

        // Check for transition to Critical (2) using stable Ref
        const prevStatus = statusRef.current[h_id] || 0;
        if (payload.status >= 1 && prevStatus < payload.status) {
          setTimeout(() => {
            setActiveAlert({ ...payload, lastUpdated: Date.now() } as SensorState);
          }, 0);
        } else if (payload.status === 0 && prevStatus >= 1) {
          setTimeout(() => {
            setActiveAlert(current => current?.h_id === h_id ? null : current);
          }, 0);
        }
        
        // Update Ref for next time
        statusRef.current[h_id] = payload.status;

        setSensors((prev) => {
          const existing = prev[h_id] || ({} as SensorState);
          const initial = initialSensorsRef.current[h_id];
          const lat = payload.lat ?? existing.lat ?? (initial?.lat != null ? Number(initial.lat) : undefined);
          const lon = payload.lon ?? existing.lon ?? (initial?.lon != null ? Number(initial.lon) : undefined);

          return {
            ...prev,
            [h_id]: { 
                ...existing, 
                ...payload,
                lat,
                lon,
                lastUpdated: Date.now() 
            }
          };
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
