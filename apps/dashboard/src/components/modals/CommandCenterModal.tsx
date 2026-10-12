import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { 
  Server, Cpu, Activity, BarChart2, FileText, Download,
  Radio, Power, MapPin
} from 'lucide-react';
import type { SensorState } from '../../types';
import { getStatusConfig } from '../../utils/statusColors';

// Subcomponents for tabs
import { SensorAnalyticsModal } from './SensorAnalyticsModal';
import { SystemAnalyticsModal } from './SystemAnalyticsModal';
import { LogsModal } from './LogsModal';

export type CommandCenterTab = 'devices' | 'simulator' | 'analytics' | 'observability' | 'incidents' | 'export';

interface CommandCenterModalProps {
  initialTab?: CommandCenterTab;
  onClose: () => void;
  sensors: Record<string, SensorState>;
  publishCommand: (h_id: string, command: any) => void;
  onLocate?: (id: string) => void;
}

export function CommandCenterModal({
  initialTab = 'devices',
  onClose,
  sensors,
  publishCommand,
  onLocate,
}: CommandCenterModalProps) {
  const [activeTab, setActiveTab] = useState<CommandCenterTab>(initialTab);

  // Sync tab if initialTab prop changes
  useEffect(() => {
    setActiveTab(initialTab);
  }, [initialTab]);

  const sensorList = Object.values(sensors);
  const activeAlerts = sensorList.filter(s => s.status > 0);

  const tabs = [
    { 
      id: 'devices' as CommandCenterTab, 
      label: 'Telemetry Fleet', 
      icon: Server, 
      badge: `${sensorList.length}`,
      desc: 'Active Nodes & Health'
    },
    { 
      id: 'simulator' as CommandCenterTab, 
      label: 'MCU Fleet Control', 
      icon: Radio, 
      desc: 'MQTT Overrides & Power'
    },
    { 
      id: 'observability' as CommandCenterTab, 
      label: 'System & Architecture', 
      icon: Cpu, 
      desc: 'Topology, Probes & Loki'
    },
    { 
      id: 'analytics' as CommandCenterTab, 
      label: 'Sensor Analytics', 
      icon: BarChart2, 
      desc: 'Heatmaps & Hourly Trends'
    },
    { 
      id: 'incidents' as CommandCenterTab, 
      label: 'Incident Logs', 
      icon: FileText, 
      badge: activeAlerts.length > 0 ? `${activeAlerts.length} Active` : undefined,
      badgeColor: activeAlerts.length > 0 ? 'bg-red-500 text-white' : undefined,
      desc: 'Historical Alarms'
    },
    { 
      id: 'export' as CommandCenterTab, 
      label: 'Data Export', 
      icon: Download, 
      desc: 'CSV / JSON Influx Dump'
    },
  ];

  return (
    <ModalOverlay
      title="Command Center & Observability Hub"
      subtitle="Unified control suite for real-time telemetry, IoT simulation, and pipeline health"
      icon={<Activity className="w-5 h-5 text-primary" />}
      onClose={onClose}
      width="max-w-7xl"
    >
      <div className="flex h-[720px] bg-white overflow-hidden">
        
        {/* Left Navigation Sidebar */}
        <div className="w-64 border-r border-slate-200 bg-slate-50/90 flex flex-col p-3 gap-1.5 shrink-0 select-none">
          <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider px-3 py-1">
            Command Center
          </div>

          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-start gap-3 px-3.5 py-2.5 rounded-xl text-left transition-all cursor-pointer ${
                  isActive
                    ? 'bg-primary text-white shadow-md'
                    : 'text-slate-600 hover:bg-slate-200/70 hover:text-slate-900'
                }`}
              >
                <Icon size={18} className={`mt-0.5 shrink-0 ${isActive ? 'text-white' : 'text-slate-500'}`} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold truncate">{tab.label}</span>
                    {tab.badge && (
                      <span className={`text-[10px] font-bold px-1.5 py-0.2 rounded ${
                        tab.badgeColor || (isActive ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700')
                      }`}>
                        {tab.badge}
                      </span>
                    )}
                  </div>
                  <span className={`text-[10px] truncate block ${isActive ? 'text-white/80' : 'text-slate-400'}`}>
                    {tab.desc}
                  </span>
                </div>
              </button>
            );
          })}

          {/* Quick Fleet Summary */}
          <div className="mt-auto p-3 bg-white rounded-xl border border-slate-200 shadow-sm text-xs">
            <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
              Fleet Status
            </div>
            <div className="flex items-center justify-between text-slate-700 font-semibold mb-1">
              <span>Total Nodes</span>
              <span className="font-mono">{sensorList.length}</span>
            </div>
            <div className="flex items-center justify-between text-emerald-600 font-semibold mb-1">
              <span>Normal</span>
              <span className="font-mono">{sensorList.filter(s => s.status === 0).length}</span>
            </div>
            <div className="flex items-center justify-between text-red-600 font-semibold">
              <span>Alerting</span>
              <span className="font-mono">{activeAlerts.length}</span>
            </div>
          </div>
        </div>

        {/* Right Tab Content View */}
        <div className={`flex-1 overflow-y-auto bg-slate-50 ${['observability', 'analytics', 'incidents'].includes(activeTab) ? 'p-0' : 'p-6'}`}>
          
          {/* TAB 1: FLEET TELEMETRY */}
          {activeTab === 'devices' && (
            <div className="flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-base font-bold text-slate-900">Active Telemetry Fleet</h3>
                  <p className="text-xs text-slate-500">Live sensor readouts transmitting via MQTT</p>
                </div>
                <div className="text-xs font-mono text-slate-500 bg-white px-3 py-1.5 rounded-lg border border-slate-200 shadow-sm">
                  {sensorList.length} Connected Nodes
                </div>
              </div>

              <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-100/75 border-b border-slate-200 text-[11px] uppercase tracking-wider text-slate-500">
                      <th className="px-4 py-3 font-semibold">Status</th>
                      <th className="px-4 py-3 font-semibold">Node ID</th>
                      <th className="px-4 py-3 font-semibold text-right">Temp (°C)</th>
                      <th className="px-4 py-3 font-semibold text-right">Smoke (PPM)</th>
                      <th className="px-4 py-3 font-semibold text-right">Flame (IR)</th>
                      <th className="px-4 py-3 font-semibold text-right">Coordinates</th>
                      <th className="px-4 py-3 font-semibold text-right">Last Update</th>
                      <th className="px-4 py-3 font-semibold text-center">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 text-xs">
                    {sensorList.length === 0 ? (
                      <tr>
                        <td colSpan={8} className="px-4 py-12 text-center text-slate-400">
                          No telemetry nodes transmitting. Start the fleet simulator.
                        </td>
                      </tr>
                    ) : (
                      sensorList.map((sensor) => {
                        const isOffline = Date.now() - sensor.lastUpdated > 15 * 60 * 1000;
                        const statusConfig = getStatusConfig(isOffline ? -1 : sensor.status);

                        return (
                          <tr key={sensor.h_id} className="hover:bg-slate-50 transition-colors">
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-2">
                                <span className="w-2 h-2 rounded-full" style={{ backgroundColor: statusConfig.hex }}></span>
                                <span className="font-semibold" style={{ color: statusConfig.hex }}>
                                  {statusConfig.label}
                                </span>
                              </div>
                            </td>
                            <td className="px-4 py-3 font-mono font-bold text-slate-900">
                              {sensor.h_id}
                            </td>
                            <td className="px-4 py-3 text-right font-mono font-medium text-slate-700">
                              {(sensor.temp || 0).toFixed(1)}°
                            </td>
                            <td className="px-4 py-3 text-right font-mono font-medium text-slate-700">
                              {(sensor.smoke || 0).toFixed(1)}
                            </td>
                            <td className="px-4 py-3 text-right font-mono font-medium text-slate-700">
                              {(sensor.flame || 0).toFixed(2)}
                            </td>
                            <td className="px-4 py-3 text-right font-mono text-slate-500 text-[11px]">
                              {sensor.lat ? `${sensor.lat.toFixed(4)}, ${sensor.lon?.toFixed(4)}` : 'No GPS'}
                            </td>
                            <td className="px-4 py-3 text-right text-slate-500 font-mono text-[11px]">
                              {sensor.lastUpdated ? new Date(sensor.lastUpdated).toLocaleTimeString() : 'Waiting'}
                            </td>
                            <td className="px-4 py-3 text-center">
                              {onLocate && (
                                <button
                                  onClick={() => {
                                    onLocate(sensor.h_id);
                                    onClose();
                                  }}
                                  className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold rounded text-[11px] transition-colors cursor-pointer"
                                >
                                  <MapPin size={12} /> Locate
                                </button>
                              )}
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 2: MCU FLEET CONTROLLER */}
          {activeTab === 'simulator' && (
            <FleetSimulatorTab sensors={sensors} publishCommand={publishCommand} />
          )}

          {/* TAB 3: OBSERVABILITY & ARCHITECTURE */}
          {activeTab === 'observability' && (
            <div className="h-full">
              <SystemAnalyticsModal onClose={onClose} embedMode />
            </div>
          )}

          {/* TAB 4: SENSOR ANALYTICS */}
          {activeTab === 'analytics' && (
            <div className="h-full">
              <SensorAnalyticsModal onClose={onClose} embedMode />
            </div>
          )}

          {/* TAB 5: INCIDENT LOGS */}
          {activeTab === 'incidents' && (
            <div className="h-full">
              <LogsModal onClose={onClose} embedMode />
            </div>
          )}

          {/* TAB 6: DATA EXPORT */}
          {activeTab === 'export' && (
            <DataExportTab />
          )}

        </div>

      </div>
    </ModalOverlay>
  );
}

// Embedded Simulator Tab
function FleetSimulatorTab({ 
  sensors, 
  publishCommand 
}: { 
  sensors: Record<string, SensorState>; 
  publishCommand: (h_id: string, cmd: any) => void;
}) {
  const [deviceList, setDeviceList] = useState<any[]>([]);

  useEffect(() => {
    fetch('/api/devices')
      .then(res => res.json())
      .then(data => {
        if (data && data.rows) {
          setDeviceList(data.rows);
        }
      })
      .catch(console.error);
  }, []);

  const handleStatus = (h_id: string, code: number) => {
    publishCommand(h_id, { status_code: code });
  };

  const handlePower = (h_id: string, on: boolean) => {
    publishCommand(h_id, { power: on ? 'on' : 'off' });
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-base font-bold text-slate-900">MCU Fleet Simulator Controller</h3>
          <p className="text-xs text-slate-500">Inject real-time MQTT telemetry overrides and trigger fire alarms</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              deviceList.forEach(d => publishCommand(d.h_id, { status_code: 0 }));
            }}
            className="px-3 py-1.5 bg-emerald-50 border border-emerald-200 text-emerald-700 hover:bg-emerald-100 text-xs font-semibold rounded-lg transition-colors cursor-pointer"
          >
            Reset All to Normal
          </button>
          <button
            onClick={() => {
              deviceList.slice(0, 2).forEach(d => publishCommand(d.h_id, { status_code: 2 }));
            }}
            className="px-3 py-1.5 bg-red-50 border border-red-200 text-red-700 hover:bg-red-100 text-xs font-semibold rounded-lg transition-colors cursor-pointer"
          >
            Simulate Fire Outbreak
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {deviceList.map((dev) => {
          const live = sensors[dev.h_id];
          const status = live?.status ?? 0;

          return (
            <div key={dev.h_id} className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between border-b border-slate-100 pb-3 mb-3">
                  <div className="flex items-center gap-2.5">
                    <span className={`w-2.5 h-2.5 rounded-full ${
                      status === 2 ? 'bg-red-600 animate-pulse' : (status === 1 ? 'bg-orange-500' : 'bg-emerald-500')
                    }`}></span>
                    <span className="font-mono font-bold text-slate-900 text-sm">{dev.h_id}</span>
                  </div>
                  <span className="text-xs font-semibold text-slate-500">{dev.barangay || 'Manila'}</span>
                </div>

                <div className="grid grid-cols-3 gap-2.5 text-center text-xs mb-3.5">
                  <div className="bg-slate-50/90 p-2.5 rounded-xl border border-slate-100">
                    <div className="text-[11px] text-slate-400 uppercase font-bold tracking-wider">Temp</div>
                    <div className="font-mono font-bold text-slate-800 text-sm mt-0.5">{(live?.temp || 0).toFixed(1)}°C</div>
                  </div>
                  <div className="bg-slate-50/90 p-2.5 rounded-xl border border-slate-100">
                    <div className="text-[11px] text-slate-400 uppercase font-bold tracking-wider">Smoke</div>
                    <div className="font-mono font-bold text-slate-800 text-sm mt-0.5">{(live?.smoke || 0).toFixed(0)} PPM</div>
                  </div>
                  <div className="bg-slate-50/90 p-2.5 rounded-xl border border-slate-100">
                    <div className="text-[11px] text-slate-400 uppercase font-bold tracking-wider">Flame</div>
                    <div className="font-mono font-bold text-slate-800 text-sm mt-0.5">{(live?.flame || 0).toFixed(2)}</div>
                  </div>
                </div>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => handleStatus(dev.h_id, 0)}
                    className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                      status === 0 ? 'bg-emerald-600 text-white shadow-xs' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                    }`}
                  >
                    Normal
                  </button>
                  <button
                    onClick={() => handleStatus(dev.h_id, 1)}
                    className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                      status === 1 ? 'bg-orange-500 text-white shadow-xs' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                    }`}
                  >
                    Warning
                  </button>
                  <button
                    onClick={() => handleStatus(dev.h_id, 2)}
                    className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                      status === 2 ? 'bg-red-600 text-white shadow-xs' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                    }`}
                  >
                    Critical
                  </button>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => handlePower(dev.h_id, true)}
                    className="p-2 text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors cursor-pointer"
                    title="Power On"
                  >
                    <Power size={15} />
                  </button>
                  <button
                    onClick={() => handlePower(dev.h_id, false)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
                    title="Power Off"
                  >
                    <Power size={15} />
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// Embedded Data Export Tab
function DataExportTab() {
  const [downloading, setDownloading] = useState(false);

  const handleExport = async (format: 'json' | 'csv') => {
    setDownloading(true);
    try {
      const res = await fetch(`/api/final-sensors/history?limit=500`);
      if (res.ok) {
        const data = await res.json();
        const blob = new Blob([JSON.stringify(data.rows || [], null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `telemetry-export-${new Date().toISOString()}.${format}`;
        a.click();
        URL.revokeObjectURL(url);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="flex flex-col gap-6 max-w-3xl">
      <div>
        <h3 className="text-base font-bold text-slate-900">Historical Telemetry Data Export</h3>
        <p className="text-xs text-slate-500">Download sanitized time-series and relational events for analysis</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[220px]">
          <div>
            <div className="flex items-center gap-2.5 text-slate-900 font-bold text-sm">
              <div className="p-2 bg-blue-50 text-blue-600 rounded-xl border border-blue-100">
                <Download size={18} />
              </div>
              <span>JSON Telemetry Dump</span>
            </div>
            <p className="text-xs text-slate-500 mt-3 leading-relaxed">
              Exports raw telemetry packets including temperature, smoke, flame, and GPS coordinates recorded in PostgreSQL.
            </p>
          </div>
          <button
            onClick={() => handleExport('json')}
            disabled={downloading}
            className="mt-6 w-full py-2.5 bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold rounded-xl transition-colors cursor-pointer flex items-center justify-center gap-2"
          >
            <Download size={14} /> Export JSON (500 records)
          </button>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between min-h-[220px]">
          <div>
            <div className="flex items-center gap-2.5 text-slate-900 font-bold text-sm">
              <div className="p-2 bg-emerald-50 text-emerald-600 rounded-xl border border-emerald-100">
                <FileText size={18} />
              </div>
              <span>Incident Audit Report</span>
            </div>
            <p className="text-xs text-slate-500 mt-3 leading-relaxed">
              Download the verified and pending fire incident history with timestamp ranges and duration metrics.
            </p>
          </div>
          <button
            onClick={() => handleExport('json')}
            disabled={downloading}
            className="mt-6 w-full py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold rounded-xl transition-colors cursor-pointer flex items-center justify-center gap-2 shadow-xs"
          >
            <Download size={14} /> Export Incidents Report
          </button>
        </div>
      </div>
    </div>
  );
}
