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
    const isLocal = window.location.hostname !== 'dev.fires.systems';
    const host = isLocal ? window.location.hostname + ':9001' : 'dev.fires.systems/mqtt';
    
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
        const payload: SensorTelemetry = JSON.parse(message.toString());
        const h_id = payload.h_id;
        
        if (!h_id) return;

        setSensors((prev) => {
          const newState = {
            ...prev,
            [h_id]: { ...prev[h_id], ...payload, lastUpdated: Date.now() }
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
