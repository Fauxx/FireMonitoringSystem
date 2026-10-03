import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Server, AlertTriangle, MapPin, Activity, Clock, Wifi } from 'lucide-react';

interface SystemAnalyticsModalProps {
  onClose: () => void;
}

export function SystemAnalyticsModal({ onClose }: SystemAnalyticsModalProps) {
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState<any>(null);
  const [status, setStatus] = useState<any>(null);
  const [performanceData, setPerformanceData] = useState<any[]>([]);
  const [days, setDays] = useState(30);

  const fetchStats = async () => {
    try {
      const res = await fetch('/api/dashboard/stats');
      if (res.ok) setStats(await res.json());
    } catch (e) {
      console.error(e);
    }
  };

  const fetchStatus = async () => {
    try {
      const res = await fetch('/api/dashboard/status');
      if (res.ok) setStatus(await res.json());
    } catch (e) {
      console.error(e);
    }
  };

  const fetchPerformance = async (selectedDays: number) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/analytics/performance?days=${selectedDays}`);
      if (res.ok) setPerformanceData(await res.json());
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
    fetchStatus();
  }, []);

  useEffect(() => {
    fetchPerformance(days);
  }, [days]);

  const getStatusColor = (s: string) => {
    switch (s?.toLowerCase()) {
      case 'operational': return 'bg-green-100 text-green-800 border-green-200';
      case 'warning': return 'bg-orange-100 text-orange-800 border-orange-200';
      case 'critical': return 'bg-red-100 text-red-800 border-red-200';
      case 'monitoring': return 'bg-blue-100 text-blue-800 border-blue-200';
      default: return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  return (
    <ModalOverlay title="System Analytics" onClose={onClose} width="max-w-5xl">
      <div className="flex flex-col gap-6 p-4">
        {/* Dashboard Stats Cards */}
        <div className="grid grid-cols-4 gap-4">
          <div className="bg-surface p-4 rounded-xl border border-surface-border flex items-center gap-4">
            <div className="p-3 bg-blue-50 text-blue-600 rounded-full"><Server size={24} /></div>
            <div>
              <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Active Devices</div>
              <div className="text-xl font-bold text-slate-900">{stats ? stats.activeDevices : '-'}</div>
            </div>
          </div>
          <div className="bg-surface p-4 rounded-xl border border-surface-border flex items-center gap-4">
            <div className="p-3 bg-red-50 text-red-600 rounded-full"><AlertTriangle size={24} /></div>
            <div>
              <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Today's Alerts</div>
              <div className="text-xl font-bold text-slate-900">{stats ? stats.todayAlerts : '-'}</div>
            </div>
          </div>
          <div className="bg-surface p-4 rounded-xl border border-surface-border flex items-center gap-4">
            <div className="p-3 bg-green-50 text-green-600 rounded-full"><Activity size={24} /></div>
            <div>
              <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">System Uptime</div>
              <div className="text-xl font-bold text-slate-900">{stats ? `${stats.systemUptime}%` : '-'}</div>
            </div>
          </div>
          <div className="bg-surface p-4 rounded-xl border border-surface-border flex items-center gap-4">
            <div className="p-3 bg-purple-50 text-purple-600 rounded-full"><MapPin size={24} /></div>
            <div>
              <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Total Locations</div>
              <div className="text-xl font-bold text-slate-900">{stats ? stats.totalLocations : '-'}</div>
            </div>
          </div>
        </div>

        {/* System Status Banner */}
        {status && (
          <div className={`p-4 rounded-xl border flex items-center justify-between ${getStatusColor(status.systemStatus)}`}>
            <div className="flex items-center gap-3">
              <Activity size={20} />
              <span className="font-bold text-sm uppercase tracking-wider">{status.systemStatus || 'Unknown Status'}</span>
            </div>
            <div className="flex items-center gap-6 text-sm">
              <span className="flex items-center gap-1"><Clock size={16}/> Last Update: {status.lastUpdateTimestamp}</span>
              <span className="flex items-center gap-1"><AlertTriangle size={16}/> Alerting: {status.alertingDevices}</span>
              <span className="flex items-center gap-1"><Wifi size={16}/> Responding: {status.respondingDevices}</span>
            </div>
          </div>
        )}

        {/* Performance Chart */}
        <div className="bg-surface p-4 rounded-xl border border-surface-border">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">System Performance History</h3>
            <div className="flex gap-2">
              {[7, 30, 60].map(d => (
                <button
                  key={d}
                  onClick={() => setDays(d)}
                  className={`px-3 py-1 text-xs rounded transition-colors ${days === d ? 'bg-primary text-white' : 'bg-base-light text-surface-muted hover:bg-surface-dim'}`}
                >
                  {d} Days
                </button>
              ))}
            </div>
          </div>
          <div className="h-[300px]">
            {loading ? (
              <div className="h-full flex items-center justify-center">
                <span className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
              </div>
            ) : performanceData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={performanceData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" fontSize={12} />
                  <YAxis fontSize={12} />
                  <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} />
                  <Legend />
                  <Area type="monotone" dataKey="uptime" name="Uptime %" stroke="#22c55e" fill="#22c55e" fillOpacity={0.3} />
                  <Area type="monotone" dataKey="max_active_devices" name="Active Devices" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.3} />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-surface-muted text-sm">No data available</div>
            )}
          </div>
        </div>
      </div>
    </ModalOverlay>
  );
}
