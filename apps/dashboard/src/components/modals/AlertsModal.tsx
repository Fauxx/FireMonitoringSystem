import { ModalOverlay } from './ModalOverlay';
import { MapPin, AlertTriangle, ShieldCheck } from 'lucide-react';
import type { SensorState } from '../../types';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  sensors: Record<string, SensorState>;
  onLocate: (id: string) => void;
}

export function AlertsModal({ isOpen, onClose, sensors, onLocate }: Props) {
  if (!isOpen) return null;

  const alerts = Object.values(sensors).filter(s => s.status > 0).sort((a, b) => b.status - a.status);

  return (
    <ModalOverlay
      title="Active Emergency Alerts"
      subtitle="Sensors detecting abnormal heat, smoke, or flame signatures"
      icon={<AlertTriangle className="w-5 h-5 text-red-600" />}
      onClose={onClose}
      width="max-w-2xl"
    >
      <div className="p-6 overflow-y-auto max-h-[60vh]">
        {alerts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-slate-400">
            <ShieldCheck size={44} className="text-emerald-500 mb-3" />
            <p className="font-semibold text-slate-700 text-sm">All Systems Normal</p>
            <p className="text-xs text-slate-400 mt-1">No active fire hazards or smoke warnings detected.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {alerts.map(alert => (
              <div 
                key={alert.h_id} 
                className={`flex items-center justify-between p-4 border rounded-xl shadow-sm transition-all ${
                  alert.status === 2 
                    ? 'border-red-200 bg-red-50/60 ring-1 ring-red-300' 
                    : 'border-orange-200 bg-orange-50/60 ring-1 ring-orange-300'
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className={`w-3 h-3 rounded-full ${alert.status === 2 ? 'bg-red-600 animate-ping' : 'bg-orange-500'}`} />
                  <div className="flex flex-col">
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-slate-900 text-sm">{alert.h_id}</span>
                      <span className={`text-[10px] font-extrabold uppercase px-2 py-0.5 rounded ${
                        alert.status === 2 ? 'bg-red-600 text-white' : 'bg-orange-500 text-white'
                      }`}>
                        {alert.status === 2 ? 'CRITICAL FIRE' : 'WARNING'}
                      </span>
                    </div>
                    <div className="text-xs text-slate-600 mt-1 font-mono">
                      Temp: {Number(alert.temp || 0).toFixed(1)}°C · Smoke: {Number(alert.smoke || 0).toFixed(0)} PPM
                    </div>
                  </div>
                </div>

                <button 
                  onClick={() => {
                    onLocate(alert.h_id);
                    onClose();
                  }}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-slate-100 text-slate-800 text-xs font-bold rounded-lg border border-slate-200 shadow-sm transition-colors cursor-pointer"
                >
                  <MapPin className="w-3.5 h-3.5 text-primary" />
                  Locate
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </ModalOverlay>
  );
}
