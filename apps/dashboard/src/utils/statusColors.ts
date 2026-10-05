export function getStatusConfig(status: number) {
  switch (status) {
    case 0:
      return { label: 'Normal', color: 'bg-green-500', hex: '#22c55e', text: 'text-green-500' };
    case 1:
      return { label: 'Warning', color: 'bg-orange-500', hex: '#f97316', text: 'text-orange-500' };
    case 2:
      return { label: 'Critical', color: 'bg-red-600', hex: '#dc2626', text: 'text-red-600' };
    case -1:
      return { label: 'Offline', color: 'bg-slate-400', hex: '#94a3b8', text: 'text-slate-400' };
    default:
      return { label: 'Unknown', color: 'bg-gray-400', hex: '#9ca3af', text: 'text-gray-400' };
  }
}
