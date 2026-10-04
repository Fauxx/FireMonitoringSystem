import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';

interface AnalyticsModalProps {
  onClose: () => void;
}

export function AnalyticsModal({ onClose }: AnalyticsModalProps) {
  const [metrics, setMetrics] = useState<any>({ cpu: [], memory: [] });
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch('/api/observability/metrics').then(res => res.json()),
      fetch('/api/observability/logs/errors').then(res => res.json())
    ])
    .then(([m, l]) => {
      // Parse Prometheus matrix data
      const parseProm = (data: any) => {
        if (!data || data.length === 0) return [];
        // Just take the first time series
        const series = data[0].values;
        return series.map((v: any) => ({
          time: new Date(v[0] * 1000).toLocaleTimeString(),
          value: parseFloat(v[1])
        }));
      };

      setMetrics({
        cpu: parseProm(m.cpu),
        memory: parseProm(m.memory)
      });
      
      // Parse Loki streams
      const parsedLogs: any[] = [];
      if (l.logs && l.logs.length > 0) {
        l.logs.forEach((stream: any) => {
          stream.values.forEach((v: any) => {
            parsedLogs.push({
              time: new Date(parseInt(v[0].substring(0, 13))).toLocaleString(),
              message: v[1],
              job: stream.stream.job
            });
          });
        });
      }
      setLogs(parsedLogs.slice(0, 15));
      setLoading(false);
    })
    .catch(err => {
      console.error(err);
      setLoading(false);
    });
  }, []);

  return (
    <ModalOverlay title="System Analytics & Observability" onClose={onClose} width="max-w-6xl">
      <div className="p-6 h-[80vh] overflow-y-auto flex flex-col gap-8 bg-gray-50">
        
        {loading ? (
          <div className="flex-1 flex items-center justify-center text-slate-500">Loading observability data...</div>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-6">
              {/* CPU Chart */}
              <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-200">
                <h3 className="text-sm font-semibold text-slate-800 mb-4">API CPU Usage (5m Rate)</h3>
                <div className="h-64 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={metrics.cpu}>
                      <defs>
                        <linearGradient id="colorCpu" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#ef4444" stopOpacity={0.8}/>
                          <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                      <XAxis dataKey="time" tick={{fontSize: 10}} stroke="#94a3b8" />
                      <YAxis tick={{fontSize: 10}} stroke="#94a3b8" />
                      <Tooltip contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                      <Area type="monotone" dataKey="value" stroke="#ef4444" fillOpacity={1} fill="url(#colorCpu)" name="CPU Seconds" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Memory Chart */}
              <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-200">
                <h3 className="text-sm font-semibold text-slate-800 mb-4">API Memory Usage (Bytes)</h3>
                <div className="h-64 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={metrics.memory}>
                      <defs>
                        <linearGradient id="colorMem" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                          <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                      <XAxis dataKey="time" tick={{fontSize: 10}} stroke="#94a3b8" />
                      <YAxis tick={{fontSize: 10}} stroke="#94a3b8" tickFormatter={(v) => (v / 1024 / 1024).toFixed(0) + 'MB'} />
                      <Tooltip contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                      <Area type="monotone" dataKey="value" stroke="#3b82f6" fillOpacity={1} fill="url(#colorMem)" name="Memory" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* Error Logs */}
            <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-200 flex-1 flex flex-col">
              <h3 className="text-sm font-semibold text-slate-800 mb-4">Recent System Errors (Loki)</h3>
              <div className="flex-1 bg-slate-900 rounded-lg p-4 overflow-y-auto font-mono text-xs text-slate-300">
                {logs.length === 0 ? (
                  <div className="text-slate-500 italic">No recent errors detected in Loki streams.</div>
                ) : (
                  logs.map((log, i) => (
                    <div key={i} className="mb-2 pb-2 border-b border-slate-800 last:border-0 break-all">
                      <span className="text-slate-500 mr-2">[{log.time}]</span>
                      <span className="text-orange-400 mr-2">[{log.job}]</span>
                      <span className="text-red-400">{log.message}</span>
                    </div>
                  ))
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </ModalOverlay>
  );
}
