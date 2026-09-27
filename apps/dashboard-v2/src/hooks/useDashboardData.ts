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

    async function fetchData() {
      try {
        const sensorsRes = await fetch('/api/final-sensors/latest?limit=1000');
        if (!sensorsRes.ok) throw new Error('API returned ' + sensorsRes.status);
        const sensorsData = await sensorsRes.json();
        
        const loadedSensors: Record<string, SensorState> = {};
        let t = 0, n = 0, w = 0, c = 0;
        
        sensorsData.rows.forEach((row: any) => {
          const payload = typeof row.raw_payload === 'string' ? JSON.parse(row.raw_payload) : (row.raw_payload || {});
          
          loadedSensors[row.h_id] = {
            h_id: row.h_id,
            lat: row.lat || 0,
            lon: row.lon || 0,
            status: row.status || 0,
            flame: payload.flame || 0,
            temp: payload.temp || 0,
            smoke: payload.smoke || 0,
            lastUpdated: new Date(row.received_at).getTime()
          };
          
          t++;
          if (row.status === 0) n++;
          else if (row.status === 1) w++;
          else if (row.status >= 2) c++;
        });
        
        setInitialSensors(loadedSensors);
        setStats({ total: t, normal: n, warning: w, critical: c });

      } catch (error) {
        console.error("Failed to load dashboard API data:", error);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [isAuthenticated]);

  return { initialSensors, stats, loading };
}
