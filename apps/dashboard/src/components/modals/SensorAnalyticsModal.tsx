import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { 
  LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer 
} from 'recharts';
import { 
  RefreshCw, Maximize2, X, Calendar, Cpu, 
  Activity, CheckCircle2, ShieldCheck, Server
} from 'lucide-react';

interface SensorAnalyticsModalProps {
  onClose: () => void;
  embedMode?: boolean;
}

export function SensorAnalyticsModal({ onClose, embedMode = false }: SensorAnalyticsModalProps) {
  const [loading, setLoading] = useState(false);
  const [devices, setDevices] = useState<{ h_id: string }[]>([]);
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
  const [expandedChart, setExpandedChart] = useState<'hourly' | 'heatmap' | null>(null);
  const [metrics, setMetrics] = useState<{ systemGenerated: { total: number }, verified: { total: number }, verificationRate: number } | null>(null);

  const setPresetRange = (days: number) => {
    const end = new Date();
    const start = new Date();
    start.setDate(end.getDate() - days);
    setStartDate(start.toISOString().split('T')[0]);
    setEndDate(end.toISOString().split('T')[0]);
  };

  const fetchDevices = async () => {
    try {
      const res = await fetch('/api/analytics/devices');
      if (res.ok) {
        const data = await res.json();
        const list = Array.isArray(data) ? data : (data.devices || data.rows || []);
        setDevices(
          list
            .map((d: any) => typeof d === 'string' ? { h_id: d } : { h_id: d.h_id || d.m || '' })
            .filter((d: any) => Boolean(d.h_id))
        );
      }
    } catch (e) {
      console.error(e);
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const deviceParam = selectedDevice ? `&device=${encodeURIComponent(selectedDevice)}&h_id=${encodeURIComponent(selectedDevice)}` : '';
      const [hourlyRes, heatmapRes, metricsRes] = await Promise.all([
        fetch(`/api/analytics/hourly?startDate=${startDate}&endDate=${endDate}${deviceParam}`),
        fetch(`/api/analytics/heatmap?type=verified&startDate=${startDate}&endDate=${endDate}${deviceParam}`),
        fetch(`/api/analytics/incident-metrics?startDate=${startDate}&endDate=${endDate}&days=30${deviceParam}`)
      ]);

      if (hourlyRes.ok) {
        const hData = await hourlyRes.json();
        if (hData.rows) {
          setHourlyData(hData.rows.map((r: any) => ({
            hour: new Date(r.timestamp_window).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            avg_temp: r.ta,
            avg_smoke: r.sa,
            avg_flame: r.fa
          })));
        } else {
          setHourlyData([]);
        }
      }
      if (heatmapRes.ok) {
        const hmData = await heatmapRes.json();
        if (hmData.heatmap) {
          setHeatmapData(Object.entries(hmData.heatmap).map(([date, val]: [string, any]) => ({
            date,
            count: val.count
          })));
        } else {
          setHeatmapData([]);
        }
      }
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

  const modalContent = (
    <div className={`flex flex-col ${embedMode ? 'h-full' : 'h-[680px]'} bg-slate-50 overflow-hidden`}>
      
      {/* Structured Filter Toolbar */}
      <div className="bg-white border-b border-slate-200 px-6 py-3 flex flex-wrap items-center justify-between gap-3 shrink-0 shadow-2xs">
        <div className="flex flex-wrap items-center gap-3">
          
          {/* Target Node Selector */}
          <div className="flex items-center gap-1.5 bg-slate-50 border border-slate-300 rounded-lg px-2.5 py-1 text-slate-700 shadow-2xs">
            <Cpu size={14} className="text-slate-400 shrink-0" />
            <select 
              value={selectedDevice} 
              onChange={e => setSelectedDevice(e.target.value)}
              className="bg-transparent text-xs font-semibold text-slate-800 outline-none cursor-pointer pr-2"
            >
              <option value="">All Fleet Devices ({devices.length > 0 ? devices.length : 10} Nodes)</option>
              {devices.map(d => {
                const id = d.h_id || (d as any).m;
                return <option key={id} value={id}>{id}</option>;
              })}
            </select>
          </div>

          {/* Date Range Inputs */}
          <div className="flex items-center gap-1 bg-slate-50 border border-slate-300 rounded-lg px-2.5 py-1 text-slate-700 shadow-2xs">
            <Calendar size={14} className="text-slate-400 shrink-0" />
            <span className="text-[11px] text-slate-400 font-semibold">From:</span>
            <input 
              type="date" 
              value={startDate} 
              onChange={e => setStartDate(e.target.value)} 
              className="bg-transparent text-xs font-semibold text-slate-800 outline-none cursor-pointer"
            />
            <span className="text-[11px] text-slate-400 font-semibold ml-1">To:</span>
            <input 
              type="date" 
              value={endDate} 
              onChange={e => setEndDate(e.target.value)} 
              className="bg-transparent text-xs font-semibold text-slate-800 outline-none cursor-pointer"
            />
          </div>

          {/* Quick Presets */}
          <div className="hidden sm:flex items-center bg-slate-100 p-0.5 rounded-lg border border-slate-200 text-xs">
            <button
              onClick={() => setPresetRange(1)}
              className="px-2.5 py-1 font-semibold text-slate-600 hover:text-slate-900 rounded-md transition-colors cursor-pointer"
            >
              24H
            </button>
            <button
              onClick={() => setPresetRange(7)}
              className="px-2.5 py-1 font-semibold text-slate-600 hover:text-slate-900 rounded-md transition-colors cursor-pointer"
            >
              7D
            </button>
            <button
              onClick={() => setPresetRange(30)}
              className="px-2.5 py-1 font-semibold text-slate-600 hover:text-slate-900 rounded-md transition-colors cursor-pointer"
            >
              30D
            </button>
          </div>
        </div>

        {/* Refresh Action Button */}
        <button 
          onClick={fetchData} 
          disabled={loading}
          className="flex items-center gap-1.5 px-3.5 py-1.5 bg-primary text-white text-xs font-bold rounded-lg hover:bg-primary-dark transition-all shadow-xs cursor-pointer disabled:opacity-50"
        >
          <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Main Scrollable Canvas */}
      <div className="flex-1 p-6 overflow-y-auto space-y-6">
        
        {/* Top 4-Column KPI Summary Cards (Spacious Card Layout) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
          
          {/* Card 1: System Generated */}
          <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[120px]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                System Alarms
              </span>
              <div className="p-1.5 bg-orange-50 text-orange-600 rounded-lg border border-orange-100">
                <Activity size={16} />
              </div>
            </div>
            <div className="my-1">
              <div className="text-2xl sm:text-3xl font-bold font-mono tracking-tight text-slate-900">
                {loading ? '...' : (metrics ? Number(metrics.systemGenerated.total).toLocaleString() : '0')}
              </div>
            </div>
            <div className="text-xs text-slate-500 font-medium">
              Automated threshold events
            </div>
          </div>

          {/* Card 2: Verified Incidents */}
          <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[120px]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Verified Fires
              </span>
              <div className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg border border-emerald-100">
                <CheckCircle2 size={16} />
              </div>
            </div>
            <div className="my-1">
              <div className="text-2xl sm:text-3xl font-bold font-mono tracking-tight text-slate-900">
                {loading ? '...' : (metrics ? Number(metrics.verified.total).toLocaleString() : '0')}
              </div>
            </div>
            <div className="text-xs text-emerald-600 font-semibold">
              Confirmed hazard alarms
            </div>
          </div>

          {/* Card 3: Verification Rate */}
          <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[120px]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Verification Rate
              </span>
              <div className="p-1.5 bg-blue-50 text-blue-600 rounded-lg border border-blue-100">
                <ShieldCheck size={16} />
              </div>
            </div>
            <div className="my-1">
              <div className="text-2xl sm:text-3xl font-bold font-mono tracking-tight text-slate-900">
                {loading ? '...' : (metrics ? `${metrics.verificationRate}%` : '0.0%')}
              </div>
            </div>
            <div className="text-xs text-blue-600 font-semibold">
              Low false-positive ratio
            </div>
          </div>

          {/* Card 4: Monitored Nodes */}
          <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[120px]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Monitoring Scope
              </span>
              <div className="p-1.5 bg-purple-50 text-purple-600 rounded-lg border border-purple-100">
                <Server size={16} />
              </div>
            </div>
            <div className="my-1">
              <div className="text-2xl sm:text-3xl font-bold font-mono tracking-tight text-slate-900">
                {loading ? '...' : `${devices.length} Nodes`}
              </div>
            </div>
            <div className="text-xs text-purple-600 font-semibold">
              Transmitting via MQTT
            </div>
          </div>

        </div>

        {/* Charts Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          
          {/* Chart 1: Hourly Multi-Variate Telemetry Trends */}
          <div className={expandedChart === 'hourly' ? "fixed inset-0 z-[2000] bg-white p-8 flex flex-col" : "bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between"}>
            <div className="flex items-center justify-between mb-3 border-b border-slate-100 pb-3">
              <div>
                <h3 className="text-sm font-bold text-slate-900 leading-tight">Hourly Telemetry Multi-Trends</h3>
                <p className="text-[11px] text-slate-500 mt-0.5">Time-series averages for Temperature, Smoke, and Flame sensors</p>
              </div>
              <div className="flex items-center gap-2">
                <div className="hidden sm:flex items-center gap-2 mr-2 text-[10px] font-semibold">
                  <span className="flex items-center gap-1 text-orange-600">
                    <span className="w-2 h-2 rounded-full bg-orange-500"></span> Temp (°C)
                  </span>
                  <span className="flex items-center gap-1 text-blue-600">
                    <span className="w-2 h-2 rounded-full bg-blue-500"></span> Smoke (PPM)
                  </span>
                  <span className="flex items-center gap-1 text-red-600">
                    <span className="w-2 h-2 rounded-full bg-red-500"></span> Flame (IR)
                  </span>
                </div>
                <button 
                  onClick={() => setExpandedChart(expandedChart === 'hourly' ? null : 'hourly')} 
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer"
                  title="Expand Chart"
                >
                  {expandedChart === 'hourly' ? <X size={18} /> : <Maximize2 size={16} />}
                </button>
              </div>
            </div>

            <div className={expandedChart === 'hourly' ? "flex-1 min-h-0" : "h-[280px]"}>
              {loading ? (
                <div className="h-full flex items-center justify-center">
                  <span className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
                </div>
              ) : hourlyData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={hourlyData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                    <XAxis dataKey="hour" fontSize={10} tickLine={false} axisLine={false} stroke="#94a3b8" />
                    <YAxis fontSize={10} tickLine={false} axisLine={false} stroke="#94a3b8" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: '#ffffff', 
                        borderColor: '#e2e8f0', 
                        borderRadius: '12px',
                        boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' 
                      }} 
                    />
                    <Line type="monotone" dataKey="avg_temp" name="Temperature (°C)" stroke="#f97316" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="avg_smoke" name="Smoke (PPM)" stroke="#3b82f6" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="avg_flame" name="Flame Intensity" stroke="#ef4444" strokeWidth={2} dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-slate-400 text-xs">
                  No telemetry points available for the selected parameters
                </div>
              )}
            </div>
          </div>

          {/* Chart 2: Daily Incident Frequency Distribution */}
          <div className={expandedChart === 'heatmap' ? "fixed inset-0 z-[2000] bg-white p-8 flex flex-col" : "bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between"}>
            <div className="flex items-center justify-between mb-3 border-b border-slate-100 pb-3">
              <div>
                <h3 className="text-sm font-bold text-slate-900 leading-tight">Daily Incident Frequency</h3>
                <p className="text-[11px] text-slate-500 mt-0.5">Verified fire incident trigger counts grouped by calendar date</p>
              </div>
              <button 
                onClick={() => setExpandedChart(expandedChart === 'heatmap' ? null : 'heatmap')} 
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer"
                title="Expand Chart"
              >
                {expandedChart === 'heatmap' ? <X size={18} /> : <Maximize2 size={16} />}
              </button>
            </div>

            <div className={expandedChart === 'heatmap' ? "flex-1 min-h-0" : "h-[280px]"}>
              {loading ? (
                <div className="h-full flex items-center justify-center">
                  <span className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
                </div>
              ) : heatmapData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={heatmapData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                    <XAxis dataKey="date" fontSize={10} tickLine={false} axisLine={false} stroke="#94a3b8" />
                    <YAxis fontSize={10} tickLine={false} axisLine={false} stroke="#94a3b8" allowDecimals={false} />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: '#ffffff', 
                        borderColor: '#e2e8f0', 
                        borderRadius: '12px',
                        boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' 
                      }} 
                    />
                    <Bar dataKey="count" name="Verified Incident Count" fill="#ef4444" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-slate-400 text-xs">
                  No incident logs found within the selected date window
                </div>
              )}
            </div>
          </div>

        </div>

      </div>

    </div>
  );

  if (embedMode) {
    return modalContent;
  }

  return (
    <ModalOverlay title="Sensor Analytics & Telemetry" onClose={onClose} width="max-w-6xl">
      {modalContent}
    </ModalOverlay>
  );
}
