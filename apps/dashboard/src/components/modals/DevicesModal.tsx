import { ModalOverlay } from './ModalOverlay';
import type { SensorState } from '../../types';
import { getStatusConfig } from '../../utils/statusColors';

interface DevicesModalProps {
  onClose: () => void;
  sensors: SensorState[];
}

export function DevicesModal({ onClose, sensors }: DevicesModalProps) {
  return (
    <ModalOverlay title="Active Telemetry Nodes" onClose={onClose}>
      
      <div className="bg-surface rounded-lg border border-surface-border overflow-hidden">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-base-dark border-b border-surface-border text-xs uppercase tracking-wider text-surface-muted">
              <th className="px-4 py-3 font-semibold">Status</th>
              <th className="px-4 py-3 font-semibold">Node ID</th>
              <th className="px-4 py-3 font-semibold text-right">Temp (°C)</th>
              <th className="px-4 py-3 font-semibold text-right">Smoke (PPM)</th>
              <th className="px-4 py-3 font-semibold text-right">Flame (IR)</th>
              <th className="px-4 py-3 font-semibold text-right">Last Update</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-surface-border">
            {sensors.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-surface-muted text-sm">
                  No active telemetry nodes transmitting.
                </td>
              </tr>
            ) : (
              sensors.map(sensor => {
                const isOffline = Date.now() - sensor.lastUpdated > 15 * 60 * 1000;
                const statusConfig = getStatusConfig(isOffline ? -1 : sensor.status);
                return (
                  <tr key={sensor.h_id} className="hover:bg-base-dark/50 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: statusConfig.hex }}></span>
                        <span className="text-xs font-semibold" style={{ color: statusConfig.hex }}>
                          {statusConfig.label}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3 font-semibold text-slate-900 text-sm">
                      {sensor.h_id}
                    </td>
                    <td className="px-4 py-3 text-right text-slate-700 font-medium font-mono text-sm">
                      {(sensor.temp || 0).toFixed(1)}
                    </td>
                    <td className="px-4 py-3 text-right text-slate-700 font-medium font-mono text-sm">
                      {(sensor.smoke || 0).toFixed(1)}
                    </td>
                    <td className="px-4 py-3 text-right text-slate-700 font-medium font-mono text-sm">
                      {(sensor.flame || 0).toFixed(0)}
                    </td>
                    <td className="px-4 py-3 text-right text-surface-muted text-xs">
                      {new Date(sensor.lastUpdated).toLocaleTimeString()}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

    </ModalOverlay>
  );
}
