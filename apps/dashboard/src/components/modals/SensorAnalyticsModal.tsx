import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { RefreshCw } from 'lucide-react';

interface SensorAnalyticsModalProps {
  onClose: () => void;
}

export function SensorAnalyticsModal({ onClose }: SensorAnalyticsModalProps) {
  const [loading, setLoading] = useState(false);
  const [devices, setDevices] = useState<{h_id: string}[]>([]);
  const [selectedDevice, setSelectedDevice] = useState('');
  
  // Dates defaulting to last 7 days
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() - 7);
    return d.toISOString().split('T')[0];
  });
  const [endDate, setEndDate] = useState(() => {
    return new Date().toISOString().split('T')[0];
  });

  const [hourlyData, setHourlyData] = useState<any[]>([]);
  const [heatmapData, setHeatmapData] = useState<any[]>([]);
  const [metrics, setMetrics] = useState<{systemGenerated: {total: number}, verified: {total: number}, verificationRate: number} | null>(null);

  const fetchDevices = async () => {
    try {
      const res = await fetch('/api/analytics/devices');
      if (res.ok) {
        const data = await res.json();
        setDevices(data);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const [hourlyRes, heatmapRes, metricsRes] = await Promise.all([
        fetch(`/api/analytics/hourly?h_id=${selectedDevice}&startDate=${startDate}&endDate=${endDate}`),
        fetch(`/api/analytics/heatmap?type=verified&start=${startDate}&end=${endDate}&h_id=${selectedDevice}`),
        fetch(`/api/analytics/incident-metrics?days=30&h_id=${selectedDevice}`)
      ]);

      if (hourlyRes.ok) setHourlyData(await hourlyRes.json());
      if (heatmapRes.ok) setHeatmapData(await heatmapRes.json());
      if (metricsRes.ok) setMetrics(await metricsRes.json());
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDevices();
  }, []);

  useEffect(() => {
    fetchData();
  }, [selectedDevice, startDate, endDate]);

  return (
    <ModalOverlay title="Sensor Analytics" onClose={onClose} width="max-w-6xl">
      <div className="flex flex-col gap-6 p-4">
        {/* Controls Row */}
        <div className="flex items-center gap-4 bg-surface p-4 rounded-xl border border-surface-border">
          <select 
            value={selectedDevice} 
            onChange={e => setSelectedDevice(e.target.value)}
            className="border border-surface-border rounded p-2 text-sm bg-base-light"
          >
            <option value="">All Devices</option>
            {devices.map(d => (
              <option key={d.h_id} value={d.h_id}>{d.h_id}</option>
            ))}
          </select>
          <input 
            type="date" 
            value={startDate} 
            onChange={e => setStartDate(e.target.value)} 
            className="border border-surface-border rounded p-2 text-sm bg-base-light"
          />
          <input 
            type="date" 
            value={endDate} 
            onChange={e => setEndDate(e.target.value)} 
            className="border border-surface-border rounded p-2 text-sm bg-base-light"
          />
          <button 
            onClick={fetchData} 
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded hover:bg-primary-dark transition-colors"
          >
            <RefreshCw size={16} /> Refresh
          </button>
        </div>

        {loading ? (
          <div className="flex justify-center items-center py-12">
            <span className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <div className="flex flex-col gap-6">
            {/* Hourly Trend Chart */}
            <div className="bg-surface p-4 rounded-xl border border-surface-border">
              <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-4">Hourly Telemetry Trends</h3>
              <div className="h-[300px]">
                {hourlyData.length > 0 ? (
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={hourlyData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="hour" fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} />
                      <Legend />
                      <Line type="monotone" dataKey="avg_temp" name="Temperature" stroke="#f97316" dot={false} />
                      <Line type="monotone" dataKey="avg_smoke" name="Smoke" stroke="#3b82f6" dot={false} />
                      <Line type="monotone" dataKey="avg_flame" name="Flame" stroke="#ef4444" dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                ) : (
                  <div className="h-full flex items-center justify-center text-surface-muted text-sm">No data available</div>
                )}
              </div>
            </div>

            {/* Incident Heatmap */}
            <div className="bg-surface p-4 rounded-xl border border-surface-border">
              <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-4">Daily Incident Frequency</h3>
              <div className="h-[250px]">
                {heatmapData.length > 0 ? (
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={heatmapData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="date" fontSize={12} />
                      <YAxis fontSize={12} />
                      <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} />
                      <Bar dataKey="count" name="Count" fill="#ef4444" />
                    </BarChart>
                  </ResponsiveContainer>
                ) : (
                   <div className="h-full flex items-center justify-center text-surface-muted text-sm">No data available</div>
                )}
              </div>
            </div>

            {/* Incident Metrics Cards */}
            <div className="grid grid-cols-3 gap-4">
              <div className="bg-surface p-4 rounded-xl border border-surface-border flex flex-col items-center justify-center">
                <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">System Generated</div>
                <div className="text-2xl font-bold text-slate-900">{metrics ? metrics.systemGenerated.total : '-'}</div>
              </div>
              <div className="bg-surface p-4 rounded-xl border border-surface-border flex flex-col items-center justify-center">
                <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Verified</div>
                <div className="text-2xl font-bold text-slate-900">{metrics ? metrics.verified.total : '-'}</div>
              </div>
              <div className="bg-surface p-4 rounded-xl border border-surface-border flex flex-col items-center justify-center">
                <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Verification Rate</div>
                <div className="text-2xl font-bold text-slate-900">{metrics ? `${metrics.verificationRate}%` : '-'}</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </ModalOverlay>
  );
}
