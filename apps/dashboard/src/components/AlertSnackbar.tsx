import { useState, useEffect } from 'react';
import { AlertTriangle, MapPin } from 'lucide-react';
import type { SensorState } from '../types';

interface AlertSnackbarProps {
  alert: SensorState | null;
  onView: (id: string) => void;
  onDismiss: () => void;
}

export function AlertSnackbar({ alert, onView, onDismiss }: AlertSnackbarProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(!!alert);
  }, [alert]);

  if (!alert) return null;

  return (
    <div className={`absolute bottom-8 left-1/2 -translate-x-1/2 z-[1000] transition-all duration-500 ease-out pointer-events-auto ${visible ? 'translate-y-0 opacity-100 scale-100' : 'translate-y-10 opacity-0 scale-95'}`}>
      <div className="bg-surface rounded-xl border-2 border-primary/40 p-4 w-[480px] shadow-2xl flex items-center gap-4 relative overflow-hidden group">
        
        {/* Animated red line indicator */}
        <div className="absolute top-0 left-0 w-full h-1 bg-primary/20">
          <div className="h-full bg-primary w-1/3 animate-[slideRight_2s_ease-in-out_infinite]"></div>
        </div>
        
        <div className="bg-primary/10 p-3 rounded-lg shrink-0">
          <AlertTriangle className="w-6 h-6 text-primary animate-pulse" strokeWidth={2} />
        </div>
        
        <div className="flex-1 pl-2">
          <div className="flex items-center gap-2 mb-1">
            <span className="w-2 h-2 bg-primary rounded-full animate-pulse"></span>
            <p className="text-[10px] font-bold text-primary uppercase tracking-wider">Critical Alert Detected</p>
          </div>
          <p className="text-lg font-semibold text-slate-900 leading-tight">Node <span className="font-bold">{alert.h_id}</span></p>
        </div>
        
        <div className="flex flex-col gap-2 shrink-0 border-l border-surface-border pl-4">
          <button 
            onClick={() => onView(alert.h_id)}
            className="flex items-center justify-center gap-2 bg-primary hover:bg-primary-dark text-white px-4 py-2 text-xs font-semibold tracking-wider uppercase transition-colors rounded-md shadow-sm"
          >
            <MapPin className="w-4 h-4" />
            Locate
          </button>
          <button 
            onClick={() => { setVisible(false); setTimeout(onDismiss, 400); }}
            className="flex items-center justify-center gap-2 text-surface-muted hover:text-slate-900 hover:bg-base-dark px-4 py-1.5 text-[10px] font-semibold tracking-wider uppercase transition-colors rounded-md"
          >
            Acknowledge
          </button>
        </div>

      </div>
    </div>
  );
}
