import { X, MapPin } from 'lucide-react';
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
    <div className="fixed inset-0 z-[1500] flex items-center justify-center pointer-events-auto">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose}></div>
      <div className="relative bg-surface w-full max-w-2xl mx-4 rounded-xl shadow-2xl border border-surface-border overflow-hidden flex flex-col max-h-[80vh]">
        
        {/* Header */}
        <div className="px-6 py-4 border-b border-surface-border flex justify-between items-center bg-base-dark">
          <h2 className="text-lg font-semibold text-slate-800">Active Alerts</h2>
          <button onClick={onClose} className="p-2 text-surface-muted hover:text-slate-900 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto">
          {alerts.length === 0 ? (
            <div className="text-center py-12 text-surface-muted">
              <p>No active alerts. System is normal.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {alerts.map(alert => (
                <div key={alert.h_id} className={`flex items-center justify-between p-4 border rounded-lg ${alert.status === 2 ? 'border-primary/50 bg-primary/5' : 'border-orange-500/50 bg-orange-500/5'}`}>
                  <div className="flex flex-col">
                    <span className="font-mono font-medium text-slate-800">{alert.h_id}</span>
                    <span className={`text-xs font-semibold uppercase ${alert.status === 2 ? 'text-primary' : 'text-orange-500'}`}>
                      {alert.status === 2 ? 'CRITICAL FIRE' : 'WARNING'}
                    </span>
                  </div>
                  <button 
                    onClick={() => {
                      onLocate(alert.h_id);
                      onClose();
                    }}
                    className="flex items-center gap-2 px-3 py-1.5 bg-base-dark hover:bg-slate-200 text-slate-800 text-sm font-medium rounded-md transition-colors"
                  >
                    <MapPin className="w-4 h-4" />
                    Locate
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
