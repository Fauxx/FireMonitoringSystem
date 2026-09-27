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
    <div className={`absolute bottom-8 left-1/2 -translate-x-1/2 z-[1000] transition-all duration-700 ease-out pointer-events-auto ${visible ? 'translate-y-0 opacity-100 scale-100' : 'translate-y-10 opacity-0 scale-95'}`}>
      <div className="bg-white/80 backdrop-blur-3xl border border-red-500/30 p-5 w-[460px] shadow-[0_12px_40px_0_rgba(239,68,68,0.15)] flex items-center gap-5 rounded-none relative overflow-hidden group">
        
        {/* Animated red line */}
        <div className="absolute top-0 left-0 w-full h-1 bg-red-500/20">
          <div className="h-full bg-red-500 w-1/3 animate-[slideRight_2s_ease-in-out_infinite]"></div>
        </div>
        
        <div className="bg-red-500/10 p-3 rounded-none border border-red-500/20 shrink-0">
          <AlertTriangle className="w-6 h-6 text-red-500 animate-pulse" strokeWidth={1.5} />
        </div>
        
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="w-1.5 h-1.5 bg-red-500 rounded-none animate-pulse"></span>
            <p className="text-[9px] font-bold text-red-500 uppercase tracking-widest">Critical Alert Detected</p>
          </div>
          <p className="text-xl font-light text-black tracking-wide leading-tight">Node <span className="font-medium">{alert.h_id}</span></p>
        </div>
        
        <div className="flex flex-col gap-2 shrink-0 border-l border-gray-200/50 pl-5">
          <button 
            onClick={() => onView(alert.h_id)}
            className="flex items-center justify-center gap-2 bg-black hover:bg-gray-800 text-white px-4 py-2 text-xs font-light tracking-widest uppercase transition-colors rounded-none"
          >
            <MapPin className="w-3.5 h-3.5" />
            Locate
          </button>
          <button 
            onClick={() => { setVisible(false); setTimeout(onDismiss, 500); }}
            className="flex items-center justify-center gap-2 text-gray-500 hover:text-black px-4 py-1.5 text-[10px] font-medium tracking-widest uppercase transition-colors rounded-none"
          >
            Acknowledge
          </button>
        </div>

      </div>
    </div>
  );
}
