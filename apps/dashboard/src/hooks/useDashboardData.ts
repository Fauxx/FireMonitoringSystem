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

    fetch('/api/final-sensors/latest')
      .then((res) => {
        if (!res.ok) throw new Error('Failed to fetch initial sensors');
        return res.json();
      })
      .then((data) => {
        const sensorMap: Record<string, SensorState> = {};
        let normal = 0, warning = 0, critical = 0;
        
        data.rows.forEach((row: any) => {
          sensorMap[row.h_id] = {
            ...row,
            lastUpdated: new Date(row.received_at).getTime()
          };
          if (row.status === 2) critical++;
          else if (row.status === 1) warning++;
          else normal++;
        });

        setInitialSensors(sensorMap);
        setStats({ total: data.rows.length, normal, warning, critical });
        setLoading(false);
      })
      .catch((err) => {
        console.error(err);
        setLoading(false);
      });
  }, [isAuthenticated]);

  return { initialSensors, stats, loading };
}
