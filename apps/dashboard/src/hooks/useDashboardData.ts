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
    // 1. Fetch devices registry metadata (public coordinates)
    const fetchDevices = fetch('/api/devices')
      .then(res => (res.ok ? res.json() : { rows: [] }))
      .catch(() => ({ rows: [] }));

    // 2. Fetch latest telemetry (requires authenticated session)
    const fetchLatest = isAuthenticated
      ? fetch('/api/final-sensors/latest')
          .then(res => (res.ok ? res.json() : { rows: [] }))
          .catch(() => ({ rows: [] }))
      : Promise.resolve({ rows: [] });

    Promise.all([fetchDevices, fetchLatest])
      .then(([devicesData, latestData]) => {
        const sensorMap: Record<string, SensorState> = {};

        // Pre-populate all devices with coordinates from registry
        if (devicesData && Array.isArray(devicesData.rows)) {
          devicesData.rows.forEach((dev: any) => {
            const lat = Number(dev.lat);
            const lon = Number(dev.lon);
            sensorMap[dev.h_id] = {
              h_id: dev.h_id,
              lat: !isNaN(lat) ? lat : undefined,
              lon: !isNaN(lon) ? lon : undefined,
              status: 0,
              lastUpdated: 0,
            };
          });
        }

        // Merge latest telemetry if available
        if (latestData && Array.isArray(latestData.rows)) {
          latestData.rows.forEach((row: any) => {
            const existingLat = sensorMap[row.h_id]?.lat;
            const existingLon = sensorMap[row.h_id]?.lon;
            const rowLat = row.lat != null ? Number(row.lat) : undefined;
            const rowLon = row.lon != null ? Number(row.lon) : undefined;

            sensorMap[row.h_id] = {
              ...(sensorMap[row.h_id] || {}),
              ...row,
              lat: rowLat != null && !isNaN(rowLat) ? rowLat : existingLat,
              lon: rowLon != null && !isNaN(rowLon) ? rowLon : existingLon,
              lastUpdated: row.received_at ? new Date(row.received_at).getTime() : 0,
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
        console.error('Dashboard data fetch error:', err);
        setLoading(false);
      });
  }, [isAuthenticated]);

  return { initialSensors, stats, loading };
}
