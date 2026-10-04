import { useState, useEffect } from 'react';
import type { SensorState } from '../types';

interface DashboardStats {
  total: number;
  normal: number;
  warning: number;
  critical: number;
}

export function useDashboardData(isAuthenticated: boolean) {
  const [initialSensors, setInitialSensors] = useState<Record<string, SensorState>>({});
  const [stats, setStats] = useState<DashboardStats>({ total: 0, normal: 0, warning: 0, critical: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isAuthenticated) return;

    Promise.all([
      fetch('/api/devices').then(res => {
        if (!res.ok) throw new Error('Failed to fetch devices');
        return res.json();
      }),
      fetch('/api/final-sensors/latest').then(res => {
        if (!res.ok) throw new Error('Failed to fetch initial sensors');
        return res.json();
      })
    ])
      .then(([devicesData, latestData]) => {
        const sensorMap: Record<string, SensorState> = {};
        
        // 1. Pre-populate all devices with coordinates
        if (devicesData && devicesData.rows) {
          devicesData.rows.forEach((dev: any) => {
            sensorMap[dev.h_id] = {
              h_id: dev.h_id,
              lat: Number(dev.lat),
              lon: Number(dev.lon),
              status: 0,
              lastUpdated: 0
            };
          });
        }

        // 2. Merge latest telemetry (if any)
        if (latestData && latestData.rows) {
          latestData.rows.forEach((row: any) => {
            sensorMap[row.h_id] = {
              ...(sensorMap[row.h_id] || {}),
              ...row,
              lat: row.lat != null ? Number(row.lat) : sensorMap[row.h_id]?.lat,
              lon: row.lon != null ? Number(row.lon) : sensorMap[row.h_id]?.lon,
              lastUpdated: new Date(row.received_at).getTime()
            };
          });
        }

        let normal = 0, warning = 0, critical = 0;
        Object.values(sensorMap).forEach((s: any) => {
          if (s.status === 2) critical++;
          else if (s.status === 1) warning++;
          else normal++;
        });

        setInitialSensors(sensorMap);
        setStats({ total: Object.keys(sensorMap).length, normal, warning, critical });
        setLoading(false);
      })
      .catch((err) => {
        console.error(err);
        setLoading(false);
      });
  }, [isAuthenticated]);

  return { initialSensors, stats, loading };
}
