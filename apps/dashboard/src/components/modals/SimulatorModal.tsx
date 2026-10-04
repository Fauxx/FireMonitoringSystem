import { useState, useEffect } from 'react';
import { Power, AlertTriangle, CheckCircle, ShieldAlert } from 'lucide-react';
import { ModalOverlay } from './ModalOverlay';
import type { SensorState } from '../../types';

interface SimulatorModalProps {
  onClose: () => void;
  publishCommand: (h_id: string, command: any) => void;
  sensors: Record<string, SensorState>;
}

interface Device {
  h_id: string;
  lat: number;
  lon: number;
  barangay: string;
}

export function SimulatorModal({ onClose, publishCommand, sensors }: SimulatorModalProps) {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    fetch('/api/devices')
      .then(res => {
        if (!res.ok) throw new Error("Failed to fetch devices: " + res.status);
        return res.json();
      })
      .then(data => {
        if (data && data.rows) {
          setDevices(data.rows.filter((d: Device) => d.h_id.startsWith('node-sim')));
        } else {
          setDevices([]);
        }
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setErrorMsg(err.message);
        setLoading(false);
      });
  }, []);

  const handlePower = (h_id: string, turnOn: boolean) => {
    publishCommand(h_id, { power: turnOn ? 'on' : 'off' });
  };

  const handleStatus = (h_id: string, status: number) => {
    publishCommand(h_id, { status_code: status });
  };

  return (
    <ModalOverlay title="Device Simulator Controller" onClose={onClose} width="max-w-3xl">
      <div className="p-6">
        <p className="text-sm text-surface-muted mb-6">
          Control active simulated devices in real-time. These nodes are registered in the database, and you can push MQTT state commands to them instantly.
        </p>

        {loading ? (
          <div className="text-center py-8 text-surface-muted">Loading registered devices...</div>
        ) : errorMsg ? (
          <div className="text-center py-8 text-red-500">Error: {errorMsg}</div>
        ) : (
          <div className="space-y-3 max-h-[60vh] overflow-y-auto pr-2">
            {devices.length === 0 ? (
              <div className="text-center py-8 text-surface-muted">No simulated devices found in registry.</div>
            ) : (
              devices.map(device => {
                // Get the LIVE status from MQTT memory, not the database snapshot
                const liveData = sensors[device.h_id];
                const currentStatus = liveData ? liveData.status : undefined;
                const isActive = liveData && (Date.now() - liveData.lastUpdated) < 30000; // active in last 30s

                return (
                  <div key={device.h_id} className="bg-base-dark rounded-lg p-4 flex items-center justify-between border border-surface-border">
                    <div className="flex flex-col">
                      <span className="font-semibold text-slate-900 font-mono text-sm">{device.h_id}</span>
                      <span className="text-xs text-surface-muted mt-1">
                        {isActive ? `Live • ${(liveData.temp ?? 0).toFixed(1)}°C` : 'Offline / Waiting'}
                      </span>
                    </div>
                    
                    <div className="flex items-center gap-6">
                      {/* Status Switcher */}
                      <div className="flex items-center bg-surface rounded-md p-1 border border-surface-border">
                        <button 
                          onClick={() => handleStatus(device.h_id, -1)}
                          className={`px-3 py-1.5 rounded text-xs font-medium transition-colors flex items-center gap-2 ${currentStatus === undefined || currentStatus === -1 ? 'bg-blue-500/20 text-blue-600' : 'text-surface-muted hover:bg-base-dark'}`}
                        >
                          <Power className="w-3 h-3" /> Auto
                        </button>
                        <button 
                          onClick={() => handleStatus(device.h_id, 0)}
                          className={`px-3 py-1.5 rounded text-xs font-medium transition-colors flex items-center gap-2 ${currentStatus === 0 ? 'bg-green-500/20 text-green-600' : 'text-surface-muted hover:bg-base-dark'}`}
                        >
                          <CheckCircle className="w-3 h-3" /> Normal
                        </button>
                        <button 
                          onClick={() => handleStatus(device.h_id, 1)}
                          className={`px-3 py-1.5 rounded text-xs font-medium transition-colors flex items-center gap-2 ${currentStatus === 1 ? 'bg-orange-500/20 text-orange-600' : 'text-surface-muted hover:bg-base-dark'}`}
                        >
                          <AlertTriangle className="w-3 h-3" /> Warning
                        </button>
                        <button 
                          onClick={() => handleStatus(device.h_id, 2)}
                          className={`px-3 py-1.5 rounded text-xs font-medium transition-colors flex items-center gap-2 ${currentStatus === 2 ? 'bg-red-500/20 text-red-600' : 'text-surface-muted hover:bg-base-dark'}`}
                        >
                          <ShieldAlert className="w-3 h-3" /> Critical
                        </button>
                      </div>

                      <div className="w-px h-8 bg-surface-border"></div>

                      {/* Power Toggles */}
                      <div className="flex gap-2">
                        <button 
                          onClick={() => handlePower(device.h_id, true)}
                          className={`p-2 rounded border transition-colors flex items-center gap-1 text-xs font-semibold ${isActive ? 'bg-green-50 border-green-200 text-green-700' : 'bg-surface border-surface-border text-surface-muted hover:text-slate-900'}`}
                          title="Start Simulation"
                        >
                          <Power className="w-3 h-3" /> ON
                        </button>
                        <button 
                          onClick={() => handlePower(device.h_id, false)}
                          className={`p-2 rounded border transition-colors flex items-center gap-1 text-xs font-semibold ${!isActive ? 'bg-red-50 border-red-200 text-red-700' : 'bg-surface border-surface-border text-surface-muted hover:text-slate-900'}`}
                          title="Pause Simulation"
                        >
                          <Power className="w-3 h-3" /> OFF
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}
      </div>
    </ModalOverlay>
  );
}
