import { createContext, useContext, useState, useCallback } from 'react';
import type { ReactNode } from 'react';

type ToastType = 'success' | 'error' | 'warning' | 'info';

interface Toast {
  id: number;
  message: string;
  type: ToastType;
}

interface ToastContextType {
  success: (message: string) => void;
  error: (message: string) => void;
  warning: (message: string) => void;
  info: (message: string) => void;
}

const ToastContext = createContext<ToastContextType | null>(null);

let nextId = 0;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const addToast = useCallback((message: string, type: ToastType) => {
    const id = nextId++;
    setToasts(prev => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 4000);
  }, []);

  const dismiss = useCallback((id: number) => {
    setToasts(prev => prev.filter(t => t.id !== id));
  }, []);

  const ctx: ToastContextType = {
    success: (msg) => addToast(msg, 'success'),
    error: (msg) => addToast(msg, 'error'),
    warning: (msg) => addToast(msg, 'warning'),
    info: (msg) => addToast(msg, 'info'),
  };

  const typeStyles: Record<ToastType, string> = {
    success: 'border-green-500/40 bg-green-50 text-green-800',
    error: 'border-primary/40 bg-red-50 text-red-800',
    warning: 'border-orange-500/40 bg-orange-50 text-orange-800',
    info: 'border-blue-500/40 bg-blue-50 text-blue-800',
  };

  const iconMap: Record<ToastType, string> = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ',
  };

  return (
    <ToastContext.Provider value={ctx}>
      {children}
      {/* Toast container — fixed bottom-right */}
      <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-2 pointer-events-none">
        {toasts.map(toast => (
          <div
            key={toast.id}
            className={`pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-lg border shadow-lg backdrop-blur-sm animate-in slide-in-from-right fade-in duration-300 ${typeStyles[toast.type]}`}
          >
            <span className="text-sm font-bold shrink-0">{iconMap[toast.type]}</span>
            <p className="text-sm font-medium flex-1">{toast.message}</p>
            <button
              onClick={() => dismiss(toast.id)}
              className="text-current opacity-50 hover:opacity-100 transition-opacity text-xs font-bold ml-2"
            >
              ✕
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within ToastProvider');
  return ctx;
}
