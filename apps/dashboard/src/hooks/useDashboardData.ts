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

    // We no longer fetch historical REST data on load.
    // The map will start completely empty and will only populate 
    // when live MQTT duplex messages arrive in real-time!
    setInitialSensors({});
    setStats({ total: 0, normal: 0, warning: 0, critical: 0 });
    setLoading(false);

  }, [isAuthenticated]);

  return { initialSensors, stats, loading };
}
