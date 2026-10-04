import { useEffect, useState } from 'react';
import { X, Flame, Thermometer, Wind, Cpu, Maximize2 } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';

interface SensorDrawerProps {
  sensor: SensorState | null;
  onClose: () => void;
}

export function SensorDrawer({ sensor, onClose }: SensorDrawerProps) {
  const [history, setHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [deviceInfo, setDeviceInfo] = useState<any>(null);
  const [activeMetric, setActiveMetric] = useState<'temp' | 'smoke' | 'flame'>('temp');
  const [isFullscreen, setIsFullscreen] = useState(false);

  useEffect(() => {
    if (!sensor) return;
    let isMounted = true;
    
    // Fetch device profile
    fetch(`/api/devices/${sensor.h_id}`)
      .then(res => res.json())
      .then(data => { if (isMounted) setDeviceInfo(data); })
      .catch(err => console.error("Failed to fetch device info", err));

    const fetchHistory = async () => {
      setLoading(true);
      try {
        const res = await fetch(`/api/telemetry/history?h_id=${sensor.h_id}&minutes=60`, {
          credentials: 'omit'
        });
        if (res.ok) {
          const data = await res.json();
          if (isMounted && data.data) {
            setHistory(data.data.map((d: any) => ({
              ...d,
              time: new Date(d.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
            })));
          }
        }
      } catch (err) {
        console.error("Failed to fetch history:", err);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    fetchHistory();
    const interval = setInterval(fetchHistory, 10000);
    
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, [sensor?.h_id]);

  if (!sensor) return null;

  const statusConfig = getStatusConfig(sensor.status);

  return (
    <div className="absolute top-0 right-0 bottom-0 w-[420px] bg-surface shadow-[2xl_0_0_rgba(0,0,0,0.1)] border-l border-surface-border z-[1000] animate-in slide-in-from-right duration-300 flex flex-col pointer-events-auto">
      
      {/* Header */}
      <div className="flex items-center justify-between p-6 border-b border-surface-border bg-base-light">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-surface border border-surface-border shadow-sm">
            <Cpu className="w-5 h-5 text-slate-700" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-slate-900 tracking-tight">{sensor.h_id}</h2>
            <p className="text-[10px] text-surface-muted font-bold uppercase tracking-wider mt-0.5">Telemetry Node</p>
          </div>
        </div>
        <button 
          onClick={onClose}
          className="p-2 rounded-md text-surface-muted hover:text-slate-900 hover:bg-surface-border transition-colors"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
        
        {/* Status Card */}
        <div className="rounded-xl border border-surface-border overflow-hidden bg-base-light shadow-sm">
          <div className={`px-4 py-2.5 border-b border-surface-border flex items-center justify-between`} style={{ backgroundColor: `${statusConfig.hex}15` }}>
            <span className="text-[10px] font-bold uppercase tracking-wider" style={{ color: statusConfig.hex }}>System Status</span>
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full animate-pulse shadow-sm" style={{ backgroundColor: statusConfig.hex }}></span>
              <span className="text-xs font-bold text-slate-900">{statusConfig.label}</span>
            </div>
          </div>
          <div className="p-4 grid grid-cols-2 gap-4 bg-surface">
            <div>
              <p className="text-[10px] text-surface-muted font-bold uppercase tracking-wider mb-1">Latitude</p>
              <p className="text-sm font-semibold text-slate-900">{Number(sensor.lat ?? 0).toFixed(5)}°</p>
            </div>
            <div>
              <p className="text-[10px] text-surface-muted font-bold uppercase tracking-wider mb-1">Longitude</p>
              <p className="text-sm font-semibold text-slate-900">{Number(sensor.lon ?? 0).toFixed(5)}°</p>
            </div>
          </div>
        </div>

        {/* Device Profile */}
        {deviceInfo && (
          <div>
            <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-3 px-1">Location & Owner Profile</h3>
            <div className="bg-surface rounded-xl border border-surface-border shadow-sm p-4 text-sm flex flex-col gap-3">
              <div className="flex justify-between">
                <span className="text-surface-muted font-medium">Owner</span>
                <span className="font-semibold text-slate-900">{deviceInfo.owner_name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-surface-muted font-medium">Contact</span>
                <span className="font-semibold text-slate-900">{deviceInfo.contact_number}</span>
              </div>
              <div className="h-px bg-surface-border"></div>
              <div className="flex justify-between">
                <span className="text-surface-muted font-medium">Barangay</span>
                <span className="font-semibold text-slate-900">{deviceInfo.barangay}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-surface-muted font-medium">Structure</span>
                <span className="font-semibold text-slate-900">{deviceInfo.structure_type}</span>
              </div>
              <div className="flex flex-col mt-1">
                <span className="text-[10px] text-surface-muted font-bold uppercase tracking-wider mb-1">Registered Address</span>
                <span className="font-medium text-slate-700">{deviceInfo.address_text}</span>
              </div>
            </div>
          </div>
        )}

        {/* Metrics Grid */}
        <div>
          <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-3 px-1">Live Telemetry</h3>
          <div className="grid grid-cols-2 gap-3">
            
            <div className="bg-surface rounded-xl border border-surface-border p-4 flex flex-col gap-2 shadow-sm">
              <div className="flex items-center justify-between">
                <Thermometer className="w-4 h-4 text-orange-500" />
                <span className="text-[10px] font-bold text-surface-muted">TMP</span>
              </div>
              <div>
                <div className="text-2xl font-bold text-slate-900 flex items-baseline gap-1">
                  {(sensor.temp || 0).toFixed(1)} <span className="text-xs text-surface-muted font-semibold">°C</span>
                </div>
              </div>
            </div>

            <div className="bg-surface rounded-xl border border-surface-border p-4 flex flex-col gap-2 shadow-sm">
              <div className="flex items-center justify-between">
                <Wind className="w-4 h-4 text-blue-500" />
                <span className="text-[10px] font-bold text-surface-muted">SMK</span>
              </div>
              <div>
                <div className="text-2xl font-bold text-slate-900 flex items-baseline gap-1">
                  {(sensor.smoke || 0).toFixed(1)} <span className="text-xs text-surface-muted font-semibold">PPM</span>
                </div>
              </div>
            </div>

            <div className="bg-surface rounded-xl border border-surface-border p-4 flex flex-col gap-2 shadow-sm">
              <div className="flex items-center justify-between">
                <Flame className="w-4 h-4 text-primary" />
                <span className="text-[10px] font-bold text-surface-muted">FLM</span>
              </div>
              <div>
                <div className="text-2xl font-bold text-slate-900 flex items-baseline gap-1">
                  {(sensor.flame || 0).toFixed(0)} <span className="text-xs text-surface-muted font-semibold">IR</span>
                </div>
              </div>
            </div>



          </div>
        </div>

        <div className={isFullscreen ? "fixed inset-0 z-[200] bg-surface p-8 flex flex-col shadow-xl" : "flex-1 min-h-[260px] flex flex-col"}>
          <div className="flex items-center justify-between mb-3 px-1">
            <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Historical Trend (1h)</h3>
            <div className="flex items-center gap-2">
              {loading && <span className="w-3 h-3 border-2 border-primary border-t-transparent rounded-full animate-spin"></span>}
              <button onClick={() => setIsFullscreen(!isFullscreen)} className="text-surface-muted hover:text-slate-900 transition-colors">
                {isFullscreen ? <X size={16} /> : <Maximize2 size={16} />}
              </button>
            </div>
          </div>
          
          <div className="flex items-center gap-2 mb-3 px-1">
            <button onClick={() => setActiveMetric('temp')} className={`text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full transition-colors ${activeMetric === 'temp' ? 'bg-orange-500 text-white' : 'bg-base-light text-surface-muted hover:bg-surface-border'}`}>Temp</button>
            <button onClick={() => setActiveMetric('smoke')} className={`text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full transition-colors ${activeMetric === 'smoke' ? 'bg-blue-500 text-white' : 'bg-base-light text-surface-muted hover:bg-surface-border'}`}>Smoke</button>
            <button onClick={() => setActiveMetric('flame')} className={`text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full transition-colors ${activeMetric === 'flame' ? 'bg-primary text-white' : 'bg-base-light text-surface-muted hover:bg-surface-border'}`}>Flame</button>
          </div>
          
          <div className={`flex-1 bg-surface rounded-xl border border-surface-border shadow-sm p-4 pb-2 ${isFullscreen ? '' : '-ml-2'}`}>
            {history.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={history} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
                  <XAxis 
                    dataKey="time" 
                    tick={{ fontSize: 9, fill: '#64748b', fontWeight: 600 }} 
                    tickLine={false}
                    axisLine={false}
                    minTickGap={20}
                  />
                  <YAxis 
                    tick={{ fontSize: 9, fill: '#64748b', fontWeight: 600 }} 
                    tickLine={false}
                    axisLine={false}
                  />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px', fontSize: '12px', fontWeight: 600, boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }}
                    itemStyle={{ fontWeight: 700 }}
                  />
                  {activeMetric === 'temp' && (
                    <Line type="monotone" dataKey="temp" stroke="#f97316" strokeWidth={2} dot={false} name="Temp (°C)" />
                  )}
                  {activeMetric === 'smoke' && (
                    <Line type="monotone" dataKey="smoke" stroke="#3b82f6" strokeWidth={2} dot={false} name="Smoke (PPM)" />
                  )}
                  {activeMetric === 'flame' && (
                    <Line type="monotone" dataKey="flame" stroke="#ef4444" strokeWidth={2} dot={false} name="Flame (IR)" />
                  )}
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div className="w-full h-full flex items-center justify-center text-xs font-semibold text-surface-muted">
                {loading ? 'Querying InfluxDB...' : 'No historical data available.'}
              </div>
            )}
          </div>
        </div>

      </div>
    </div>
  );
}
