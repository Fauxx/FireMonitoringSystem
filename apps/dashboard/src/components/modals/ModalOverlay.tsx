import React from 'react';
import { X } from 'lucide-react';

interface ModalOverlayProps {
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  onClose: () => void;
  children: React.ReactNode;
  width?: string;
  headerActions?: React.ReactNode;
}

export function ModalOverlay({ 
  title, 
  subtitle, 
  icon, 
  onClose, 
  children, 
  width = "max-w-5xl",
  headerActions 
}: ModalOverlayProps) {
  return (
    <div className="fixed inset-0 z-[2000] flex items-center justify-center p-4 md:p-6 pointer-events-auto">
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-slate-950/60 backdrop-blur-md transition-opacity animate-in fade-in duration-200"
        onClick={onClose}
      />
      
      {/* Modal Dialog */}
      <div className={`relative w-full ${width} bg-white rounded-2xl shadow-2xl border border-slate-200/80 flex flex-col max-h-[90vh] overflow-hidden animate-in zoom-in-95 duration-200 z-10`}>
        
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200 bg-slate-50/90 backdrop-blur-sm shrink-0">
          <div className="flex items-center gap-3">
            {icon && (
              <div className="p-2 rounded-xl bg-white border border-slate-200 text-slate-800 shadow-sm">
                {icon}
              </div>
            )}
            <div>
              <h2 className="text-base font-bold text-slate-900 leading-tight">{title}</h2>
              {subtitle && (
                <p className="text-xs text-slate-500 font-medium mt-0.5">{subtitle}</p>
              )}
            </div>
          </div>

          <div className="flex items-center gap-2">
            {headerActions}
            <button 
              onClick={onClose}
              className="p-2 rounded-lg text-slate-400 hover:text-slate-800 hover:bg-slate-200/70 transition-colors cursor-pointer"
              title="Close (Esc)"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>
        
        {/* Body */}
        <div className="flex-1 overflow-y-auto bg-slate-50">
          {children}
        </div>
        
      </div>
    </div>
  );
}
