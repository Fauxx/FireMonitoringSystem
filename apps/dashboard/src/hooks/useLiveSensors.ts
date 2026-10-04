import { useState, useEffect, useCallback, useRef } from 'react';
import mqtt from 'mqtt';
import type { SensorState, SensorTelemetry } from '../types';

export function useLiveSensors(initialSensors: Record<string, SensorState>) {
  const [sensors, setSensors] = useState<Record<string, SensorState>>({});
  const [activeAlert, setActiveAlert] = useState<SensorState | null>(null);
  const [mqttClient, setMqttClient] = useState<mqtt.MqttClient | null>(null);

  useEffect(() => {
    if (Object.keys(initialSensors).length > 0) {
      setSensors((prev) => {
        const merged = { ...prev };
        for (const [id, sensor] of Object.entries(initialSensors)) {
          if (!merged[id]) {
            merged[id] = sensor;
          } else {
            // Keep live telemetry but ensure missing static DB fields (lat/lon) are restored
            merged[id] = {
              ...merged[id],
              lat: merged[id].lat ?? (sensor.lat ? Number(sensor.lat) : undefined),
              lon: merged[id].lon ?? (sensor.lon ? Number(sensor.lon) : undefined),
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
        const h_id: string = raw.h_id || raw.device_id;
        if (!h_id) return;
        
        const payload: SensorTelemetry = {
            h_id: h_id,
            lat: raw.lat,
            lon: raw.lon,
            status: raw.status ?? raw.status_code ?? 0,
            temp: raw.temp ?? raw.readings?.temperature_c,
            smoke: raw.smoke ?? raw.readings?.smoke_ppm,
            flame: raw.flame ?? raw.readings?.flame_intensity,
            _time: raw._time ?? raw.timestamp
        };

        // Check for transition to Critical (2) using stable Ref
        const prevStatus = statusRef.current[h_id] || 0;
        if (payload.status >= 1 && prevStatus < payload.status) {
          // It's a new alert (warning or critical) or escalating from warning to critical
          setTimeout(() => {
            setActiveAlert({ ...payload, lastUpdated: Date.now() } as SensorState);
          }, 0);
        } else if (payload.status === 0 && prevStatus >= 1) {
          // Auto-dismiss if it returns to normal
          setTimeout(() => {
            setActiveAlert(current => current?.h_id === h_id ? null : current);
          }, 0);
        }
        
        // Update Ref for next time
        statusRef.current[h_id] = payload.status;

        setSensors((prev) => {
          const existing = prev[h_id] || {} as SensorState;
          return {
            ...prev,
            [h_id]: { 
                ...existing, 
                ...payload,
                lat: payload.lat ?? existing.lat,
                lon: payload.lon ?? existing.lon,
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
