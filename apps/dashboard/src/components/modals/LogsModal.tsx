import { useState, useEffect } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { Clock, AlertTriangle } from 'lucide-react';
import { getStatusConfig } from '../../utils/statusColors';

interface LogsModalProps {
  onClose: () => void;
}

export function LogsModal({ onClose }: LogsModalProps) {
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    
    const fetchLogs = async () => {
      try {
        const res = await fetch('/api/incidents');
        if (res.ok) {
          const data = await res.json();
          if (isMounted) {
            setLogs([...(data.pending || []), ...(data.verified || [])].sort((a, b) => new Date(b.start_time).getTime() - new Date(a.start_time).getTime()));
          }
        }
      } catch (err) {
        console.error("Failed to fetch logs:", err);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    fetchLogs();
    return () => { isMounted = false; };
  }, []);

  return (
    <ModalOverlay title="System Incident Logs" onClose={onClose} width="max-w-5xl">
      <div className="bg-surface rounded-lg border border-surface-border overflow-hidden">
        
        {loading ? (
          <div className="flex flex-col items-center justify-center py-16 text-surface-muted">
            <span className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin mb-4"></span>
            <p className="font-semibold tracking-wider text-sm">Querying PostgreSQL...</p>
          </div>
        ) : (
          <div className="overflow-x-auto max-h-[60vh] overflow-y-auto">
            <table className="w-full text-left border-collapse">
              <thead className="sticky top-0 z-10 bg-base-dark border-b border-surface-border text-xs uppercase tracking-wider text-surface-muted">
                <tr>
                  <th className="px-4 py-3 font-semibold">Incident Time</th>
                  <th className="px-4 py-3 font-semibold">Node ID</th>
                  <th className="px-4 py-3 font-semibold">Severity</th>
                  <th className="px-4 py-3 font-semibold">Duration</th>
                  <th className="px-4 py-3 font-semibold">Stage</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-border">
                {logs.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-surface-muted text-sm font-medium">
                      No historical incidents found in database.
                    </td>
                  </tr>
                ) : (
                  logs.map((log, idx) => {
                    const statusConfig = getStatusConfig(log.alert_level || log.status || 2);
                    
                    return (
                      <tr key={idx} className="hover:bg-base-dark/50 transition-colors">
                        <td className="px-4 py-3 text-sm text-slate-700 font-mono">
                          {new Date(log.start_time).toLocaleString()}
                        </td>
                        <td className="px-4 py-3 font-semibold text-slate-900 text-sm">
                          {log.device_id}
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <span className="w-2 h-2 rounded-full" style={{ backgroundColor: statusConfig.hex }}></span>
                            <span className="text-xs font-bold" style={{ color: statusConfig.hex }}>
                              {statusConfig.label}
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-sm text-slate-700 font-mono flex items-center gap-2">
                          <Clock className="w-3.5 h-3.5 text-surface-muted" />
                          {log.duration}
                        </td>
                        <td className="px-4 py-3">
                          <span className={`px-2 py-1 text-[10px] font-bold uppercase tracking-wider rounded-md ${
                            log.event_stage === 'ongoing' ? 'bg-primary/10 text-primary' : 'bg-surface-border text-slate-600'
                          }`}>
                            {log.event_stage}
                          </span>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}

      </div>
    </ModalOverlay>
  );
}
