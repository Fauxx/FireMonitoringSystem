import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { AreaChart, Area, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Server, AlertTriangle, MapPin, Activity, Clock, Wifi, Maximize2, X, LayoutDashboard, Cpu, Database, Globe } from 'lucide-react';

interface SystemAnalyticsModalProps {
  onClose: () => void;
}

export function SystemAnalyticsModal({ onClose }: SystemAnalyticsModalProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'application' | 'infrastructure' | 'data'>('overview');
  
  // Overview State
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState<any>(null);
  const [status, setStatus] = useState<any>(null);
  const [performanceData, setPerformanceData] = useState<any[]>([]);
  const [days, setDays] = useState(30);
  const [isFullscreen, setIsFullscreen] = useState<string | null>(null);

  // Application State
  const [selectedRoute, setSelectedRoute] = useState('all');
  const [appMetrics, setAppMetrics] = useState<any>(null);

  // Infra & Data State
  const [infraMetrics, setInfraMetrics] = useState<any>(null);
  const [dataMetrics, setDataMetrics] = useState<any>(null);

  // Fetch functions for Overview
  const fetchOverviewData = async () => {
    try {
      const [resStats, resStatus] = await Promise.all([
        fetch('/api/dashboard/stats'),
        fetch('/api/dashboard/status')
      ]);
      if (resStats.ok) setStats(await resStats.json());
      if (resStatus.ok) setStatus(await resStatus.json());
    } catch (e) {
      console.error(e);
    }
  };

  const fetchPerformance = async (selectedDays: number) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/analytics/performance?days=${selectedDays}`);
      if (res.ok) {
        const data = await res.json();
        setPerformanceData(data.history || []);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  // Fetch functions for Observability
  const fetchAppMetrics = async () => {
    try {
      const res = await fetch(`/api/observability/app/metrics?route=${selectedRoute}`);
      if (res.ok) {
        const data = await res.json();
        // Transform Prometheus data format to Recharts format
        let rpsValue = '0';
        if (data.rps && data.rps.length > 0) {
          rpsValue = parseFloat(data.rps[0].value[1]).toFixed(2);
        }
        
        let latencyChartData = [];
        if (data.latency && data.latency.length > 0) {
          latencyChartData = data.latency[0].values.map((v: any) => ({
            time: new Date(v[0] * 1000).toLocaleTimeString(),
            latency: parseFloat(v[1])
          }));
        }
        
        setAppMetrics({ rps: rpsValue, latencyChartData });
      }
    } catch (e) { console.error(e); }
  };

  const fetchInfraMetrics = async () => {
    try {
      const res = await fetch(`/api/observability/infra/health`);
      if (res.ok) {
        const data = await res.json();
        let chartData: any[] = [];
        if (data.cpu && data.cpu.length > 0 && data.memory && data.memory.length > 0) {
           chartData = data.cpu[0].values.map((v: any, idx: number) => ({
             time: new Date(v[0] * 1000).toLocaleTimeString(),
             cpu: parseFloat(v[1]),
             memory: data.memory[0] && data.memory[0].values[idx] ? parseFloat(data.memory[0].values[idx][1]) : 0
           }));
        }
        
        let currentCpu = chartData.length > 0 ? chartData[chartData.length - 1].cpu.toFixed(1) : 0;
        let currentMem = chartData.length > 0 ? chartData[chartData.length - 1].memory.toFixed(1) : 0;
        
        setInfraMetrics({ currentCpu, currentMem, chartData });
      }
    } catch (e) { console.error(e); }
  };

  const fetchDataMetrics = async () => {
    try {
      const res = await fetch(`/api/observability/data/health`);
      if (res.ok) {
        const data = await res.json();
        let chartData: any[] = [];
        if (data.mqtt && data.mqtt.length > 0 && data.postgres && data.postgres.length > 0) {
           chartData = data.postgres[0].values.map((v: any, idx: number) => ({
             time: new Date(v[0] * 1000).toLocaleTimeString(),
             postgres: parseFloat(v[1]),
             mqtt: data.mqtt[0] && data.mqtt[0].values[idx] ? parseFloat(data.mqtt[0].values[idx][1]) : 0
           }));
        }
        let currentMqtt = chartData.length > 0 ? chartData[chartData.length - 1].mqtt : 0;
        let currentPg = chartData.length > 0 ? chartData[chartData.length - 1].postgres : 0;
        
        setDataMetrics({ currentMqtt, currentPg, chartData });
      }
    } catch (e) { console.error(e); }
  };

  useEffect(() => {
    fetchOverviewData();
  }, []);

  useEffect(() => {
    if (activeTab === 'overview') fetchPerformance(days);
    if (activeTab === 'application') fetchAppMetrics();
    if (activeTab === 'infrastructure') fetchInfraMetrics();
    if (activeTab === 'data') fetchDataMetrics();
  }, [activeTab, days, selectedRoute]);

  const getStatusColor = (s: string) => {
    switch (s?.toLowerCase()) {
      case 'operational': return 'bg-green-100 text-green-800 border-green-200';
      case 'warning': return 'bg-orange-100 text-orange-800 border-orange-200';
      case 'critical': return 'bg-red-100 text-red-800 border-red-200';
      case 'monitoring': return 'bg-blue-100 text-blue-800 border-blue-200';
      default: return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  const navItems = [
    { id: 'overview', label: 'Overview', icon: LayoutDashboard },
    { id: 'application', label: 'Application', icon: Globe },
    { id: 'infrastructure', label: 'Infrastructure', icon: Cpu },
    { id: 'data', label: 'Data Layer', icon: Database }
  ];

  return (
    <ModalOverlay title="System Analytics" onClose={onClose} width="max-w-6xl">
      <div className="flex h-[600px] bg-white rounded-b-xl overflow-hidden">
        {/* Sidebar */}
        <div className="w-64 border-r border-surface-border bg-base-light flex flex-col p-4 gap-2">
          {navItems.map(item => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id as any)}
                className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-semibold transition-all ${
                  isActive ? 'bg-primary text-white shadow-md' : 'text-surface-muted hover:bg-surface hover:text-slate-900'
                }`}
              >
                <Icon size={18} />
                {item.label}
              </button>
            );
          })}
        </div>

        {/* Main Content */}
        <div className="flex-1 p-6 overflow-y-auto bg-slate-50">
          
          {/* OVERVIEW TAB */}
          {activeTab === 'overview' && (
            <div className="flex flex-col gap-6">
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-white p-4 rounded-xl border border-surface-border shadow-sm flex items-center gap-4">
                  <div className="p-3 bg-blue-50 text-blue-600 rounded-full"><Server size={24} /></div>
                  <div>
                    <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Active Devices</div>
                    <div className="text-xl font-bold text-slate-900">{stats ? stats.activeDevices : '-'}</div>
                  </div>
                </div>
                <div className="bg-white p-4 rounded-xl border border-surface-border shadow-sm flex items-center gap-4">
                  <div className="p-3 bg-red-50 text-red-600 rounded-full"><AlertTriangle size={24} /></div>
                  <div>
                    <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Today's Alerts</div>
                    <div className="text-xl font-bold text-slate-900">{stats ? stats.todayAlerts : '-'}</div>
                  </div>
                </div>
                <div className="bg-white p-4 rounded-xl border border-surface-border shadow-sm flex items-center gap-4">
                  <div className="p-3 bg-green-50 text-green-600 rounded-full"><Activity size={24} /></div>
                  <div>
                    <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">System Uptime</div>
                    <div className="text-xl font-bold text-slate-900">{stats ? `${stats.systemUptime}%` : '-'}</div>
                  </div>
                </div>
                <div className="bg-white p-4 rounded-xl border border-surface-border shadow-sm flex items-center gap-4">
                  <div className="p-3 bg-purple-50 text-purple-600 rounded-full"><MapPin size={24} /></div>
                  <div>
                    <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Total Locations</div>
                    <div className="text-xl font-bold text-slate-900">{stats ? stats.totalLocations : '-'}</div>
                  </div>
                </div>
              </div>

              {status && (
                <div className={`p-4 rounded-xl border flex flex-col md:flex-row items-center justify-between ${getStatusColor(status.systemStatus)}`}>
                  <div className="flex items-center gap-3">
                    <Activity size={20} />
                    <span className="font-bold text-sm uppercase tracking-wider">{status.systemStatus || 'Unknown Status'}</span>
                  </div>
                  <div className="flex items-center gap-6 text-sm mt-2 md:mt-0">
                    <span className="flex items-center gap-1"><Clock size={16}/> Last Update: {status.lastUpdateTimestamp}</span>
                    <span className="flex items-center gap-1"><AlertTriangle size={16}/> Alerting: {status.alertingDevices}</span>
                    <span className="flex items-center gap-1"><Wifi size={16}/> Responding: {status.respondingDevices}</span>
                  </div>
                </div>
              )}

              <div className={isFullscreen === 'overview' ? "fixed inset-0 z-[200] bg-white p-8 flex flex-col" : "bg-white p-4 rounded-xl border border-surface-border shadow-sm"}>
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">System Performance History</h3>
                  <div className="flex gap-2 items-center">
                    {[7, 30, 60].map(d => (
                      <button
                        key={d}
                        onClick={() => setDays(d)}
                        className={`px-3 py-1 text-xs rounded transition-colors ${days === d ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}
                      >
                        {d} Days
                      </button>
                    ))}
                    <button onClick={() => setIsFullscreen(isFullscreen === 'overview' ? null : 'overview')} className="ml-2 p-1 text-slate-400 hover:text-slate-900 transition-colors">
                      {isFullscreen === 'overview' ? <X size={20} /> : <Maximize2 size={20} />}
                    </button>
                  </div>
                </div>
                <div className={isFullscreen === 'overview' ? "flex-1 min-h-0" : "h-[300px]"}>
                  {loading ? (
                    <div className="h-full flex items-center justify-center">
                      <span className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
                    </div>
                  ) : performanceData.length > 0 ? (
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={performanceData}>
                        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                        <XAxis dataKey="date" fontSize={12} tickLine={false} axisLine={false} />
                        <YAxis fontSize={12} tickLine={false} axisLine={false} />
                        <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                        <Legend />
                        <Area type="monotone" dataKey="uptime" name="Uptime %" stroke="#22c55e" strokeWidth={2} fill="#22c55e" fillOpacity={0.1} />
                        <Area type="monotone" dataKey="max_active_devices" name="Active Devices" stroke="#3b82f6" strokeWidth={2} fill="#3b82f6" fillOpacity={0.1} />
                      </AreaChart>
                    </ResponsiveContainer>
                  ) : (
                    <div className="h-full flex items-center justify-center text-slate-400 text-sm">No data available</div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* APPLICATION TAB */}
          {activeTab === 'application' && (
            <div className="flex flex-col gap-6">
               <div className="grid grid-cols-2 gap-4">
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Total Request Rate</div>
                   <div className="text-3xl font-bold text-slate-900">{appMetrics?.rps ? `${appMetrics.rps} req/s` : '0 req/s'}</div>
                 </div>
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Global Error Rate</div>
                   <div className="text-3xl font-bold text-red-600">0.02%</div>
                 </div>
               </div>

               <div className={isFullscreen === 'app' ? "fixed inset-0 z-[200] bg-white p-8 flex flex-col" : "bg-white p-4 rounded-xl border border-surface-border shadow-sm"}>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">API Latency Trend (P95)</h3>
                    <div className="flex gap-4 items-center">
                      <select 
                        value={selectedRoute}
                        onChange={e => setSelectedRoute(e.target.value)}
                        className="bg-slate-50 border border-slate-200 text-sm rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-primary/20"
                      >
                        <option value="all">All Routes</option>
                        <option value="/api/analytics/performance">/api/analytics/performance</option>
                        <option value="/api/dashboard/stats">/api/dashboard/stats</option>
                        <option value="/api/telemetry">/api/telemetry</option>
                        <option value="/auth/login">/auth/login</option>
                        <option value="/metrics">/metrics</option>
                      </select>
                      <button onClick={() => setIsFullscreen(isFullscreen === 'app' ? null : 'app')} className="p-1 text-slate-400 hover:text-slate-900 transition-colors">
                        {isFullscreen === 'app' ? <X size={20} /> : <Maximize2 size={20} />}
                      </button>
                    </div>
                  </div>
                  <div className={isFullscreen === 'app' ? "flex-1 min-h-0" : "h-[300px]"}>
                    {!appMetrics?.latencyChartData || appMetrics.latencyChartData.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-slate-400 text-sm">No data available for this route</div>
                    ) : (
                      <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={appMetrics.latencyChartData}>
                          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                          <XAxis dataKey="time" fontSize={10} tickLine={false} axisLine={false} minTickGap={30} />
                          <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(val) => `${(val*1000).toFixed(0)}ms`} />
                          <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} formatter={(val: any) => [`${(Number(val)*1000).toFixed(1)} ms`, 'Latency (P95)']} />
                          <Line type="monotone" dataKey="latency" name="Latency (P95)" stroke="#6366f1" strokeWidth={2} dot={false} />
                        </LineChart>
                      </ResponsiveContainer>
                    )}
                  </div>
               </div>
            </div>
          )}

          {/* INFRASTRUCTURE TAB */}
          {activeTab === 'infrastructure' && (
            <div className="flex flex-col gap-6">
               <div className="grid grid-cols-2 gap-4">
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Cluster CPU Usage</div>
                   <div className="text-3xl font-bold text-slate-900">{infraMetrics?.currentCpu || '0'}%</div>
                 </div>
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Cluster Memory Usage</div>
                   <div className="text-3xl font-bold text-slate-900">{infraMetrics?.currentMem || '0'}%</div>
                 </div>
               </div>

               <div className={isFullscreen === 'infra' ? "fixed inset-0 z-[200] bg-white p-8 flex flex-col" : "bg-white p-4 rounded-xl border border-surface-border shadow-sm"}>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Node Saturation Trend</h3>
                    <button onClick={() => setIsFullscreen(isFullscreen === 'infra' ? null : 'infra')} className="p-1 text-slate-400 hover:text-slate-900 transition-colors">
                      {isFullscreen === 'infra' ? <X size={20} /> : <Maximize2 size={20} />}
                    </button>
                  </div>
                  <div className={isFullscreen === 'infra' ? "flex-1 min-h-0" : "h-[300px]"}>
                    {!infraMetrics?.chartData || infraMetrics.chartData.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-slate-400 text-sm">No infrastructure data available</div>
                    ) : (
                      <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={infraMetrics.chartData}>
                          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                          <XAxis dataKey="time" fontSize={10} tickLine={false} axisLine={false} minTickGap={30} />
                          <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(val) => `${val}%`} />
                          <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} />
                          <Legend />
                          <Area type="monotone" dataKey="cpu" name="CPU Usage %" stroke="#f59e0b" strokeWidth={2} fill="#f59e0b" fillOpacity={0.1} />
                          <Area type="monotone" dataKey="memory" name="Memory Usage %" stroke="#8b5cf6" strokeWidth={2} fill="#8b5cf6" fillOpacity={0.1} />
                        </AreaChart>
                      </ResponsiveContainer>
                    )}
                  </div>
               </div>
            </div>
          )}

          {/* DATA LAYER TAB */}
          {activeTab === 'data' && (
            <div className="flex flex-col gap-6">
               <div className="grid grid-cols-2 gap-4">
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Active MQTT Connections</div>
                   <div className="text-3xl font-bold text-slate-900">{dataMetrics?.currentMqtt || '0'}</div>
                 </div>
                 <div className="bg-white p-6 rounded-xl border border-surface-border shadow-sm">
                   <div className="text-[10px] font-bold text-surface-muted uppercase tracking-wider mb-2">Active DB Connections</div>
                   <div className="text-3xl font-bold text-slate-900">{dataMetrics?.currentPg || '0'}</div>
                 </div>
               </div>

               <div className={isFullscreen === 'data' ? "fixed inset-0 z-[200] bg-white p-8 flex flex-col" : "bg-white p-4 rounded-xl border border-surface-border shadow-sm"}>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-[10px] font-bold text-surface-muted uppercase tracking-wider">Data Layer Connections Trend</h3>
                    <button onClick={() => setIsFullscreen(isFullscreen === 'data' ? null : 'data')} className="p-1 text-slate-400 hover:text-slate-900 transition-colors">
                      {isFullscreen === 'data' ? <X size={20} /> : <Maximize2 size={20} />}
                    </button>
                  </div>
                  <div className={isFullscreen === 'data' ? "flex-1 min-h-0" : "h-[300px]"}>
                    {!dataMetrics?.chartData || dataMetrics.chartData.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-slate-400 text-sm">No data layer metrics available</div>
                    ) : (
                      <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={dataMetrics.chartData}>
                          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                          <XAxis dataKey="time" fontSize={10} tickLine={false} axisLine={false} minTickGap={30} />
                          <YAxis fontSize={12} tickLine={false} axisLine={false} />
                          <Tooltip contentStyle={{ backgroundColor: '#ffffff', borderColor: '#e2e8f0', borderRadius: '8px' }} />
                          <Legend />
                          <Line type="monotone" dataKey="postgres" name="Postgres Active Sessions" stroke="#3b82f6" strokeWidth={2} dot={false} />
                          <Line type="monotone" dataKey="mqtt" name="MQTT Active Subscriptions" stroke="#ec4899" strokeWidth={2} dot={false} />
                        </LineChart>
                      </ResponsiveContainer>
                    )}
                  </div>
               </div>
            </div>
          )}

        </div>
      </div>
    </ModalOverlay>
  );
}
