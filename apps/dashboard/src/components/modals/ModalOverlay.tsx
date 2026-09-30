import { X } from 'lucide-react';

interface ModalOverlayProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  width?: string;
}

export function ModalOverlay({ title, onClose, children, width = "max-w-4xl" }: ModalOverlayProps) {
  return (
    <div className="absolute inset-0 z-[2000] flex items-center justify-center pointer-events-auto">
      {/* Dimmed backdrop */}
      <div 
        className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm animate-in fade-in duration-200"
        onClick={onClose}
      />
      
      {/* Modal Dialog */}
      <div className={`relative w-full ${width} bg-surface rounded-xl shadow-2xl border border-surface-border flex flex-col max-h-[85vh] animate-in zoom-in-95 duration-200 mx-4`}>
        
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-surface-border bg-base-dark rounded-t-xl">
          <h2 className="text-lg font-semibold text-slate-900">{title}</h2>
          <button 
            onClick={onClose}
            className="p-2 -mr-2 rounded-md text-surface-muted hover:text-slate-900 hover:bg-surface-border transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        
        {/* Body */}
        <div className="flex-1 overflow-y-auto p-6 bg-surface rounded-b-xl">
          {children}
        </div>
        
      </div>
    </div>
  );
}
