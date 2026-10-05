import { useState, useRef, useEffect } from 'react';
import { Search, Bell, Settings, Activity, Server, FileText, Download, BarChart2, LogOut } from 'lucide-react';

interface Stats {
  total: number;
  normal: number;
  warning: number;
  critical: number;
  offline?: number;
}

interface FloatingTopBarProps {
  onSearch: (id: string) => void;
  onOpenModal: (action: string) => void;
  stats: Stats;
}

export function FloatingTopBar({ onSearch, onOpenModal, stats }: FloatingTopBarProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchTerm) onSearch(searchTerm);
  };

  const handleLogout = async () => {
    try {
      await fetch('/auth/logout', { method: 'POST' });
      window.location.reload();
    } catch (err) {
      console.error('Logout failed', err);
    }
  };

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const navItems = [
    { icon: <Server className="w-4 h-4" />, label: "Devices", action: "devices" },
    { icon: <Activity className="w-4 h-4" />, label: "Simulation Controller", action: "simulator" },
    { icon: <BarChart2 className="w-4 h-4" />, label: "Sensor Analytics", action: "analytics" },
    { icon: <Activity className="w-4 h-4" />, label: "System Analytics", action: "system" },
    { icon: <FileText className="w-4 h-4" />, label: "Incident Logs", action: "logs" },
    { icon: <Download className="w-4 h-4" />, label: "Export Data", action: "export" },
  ];

  return (
    <div className="absolute top-6 left-6 right-6 z-[1000] flex justify-between items-start pointer-events-none">
      
      {/* Brand & Search */}
      <div className="flex flex-col gap-3 pointer-events-auto">
        <div className="bg-surface px-5 py-3.5 rounded-lg border border-surface-border shadow-md flex items-center gap-4">
          <div className="w-1.5 h-1.5 bg-primary rounded-full"></div>
          <div>
            <h1 className="font-semibold text-slate-900 text-sm leading-tight">FireMonitor</h1>
            <p className="text-[10px] text-surface-muted font-medium uppercase tracking-wider">Platform</p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="bg-surface rounded-lg border border-surface-border shadow-md flex items-center overflow-hidden w-80 transition-all focus-within:ring-2 focus-within:ring-primary/50">
          <div className="pl-4 py-2.5 text-surface-muted">
            <Search className="w-4 h-4" />
          </div>
          <input 
            type="text" 
            placeholder="Search Node ID..." 
            className="w-full py-2.5 px-3 bg-transparent outline-none text-sm text-slate-900 placeholder:text-surface-muted"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </form>
      </div>

      {/* Live Stats */}
      <div className="bg-surface rounded-lg border border-surface-border shadow-md flex items-center px-6 py-4 gap-8 pointer-events-auto">
        <div className="flex flex-col items-center">
          <span className="text-xl font-semibold text-slate-900">{stats.total}</span>
          <span className="text-[10px] text-surface-muted font-medium uppercase tracking-wider mt-1">Total</span>
        </div>
        
        <div className="w-px h-8 bg-surface-border"></div>
        
        <button 
          onClick={() => onOpenModal('alerts')}
          className="flex gap-6 hover:bg-base-dark p-2 rounded-md transition-colors cursor-pointer"
          title="View Active Alerts"
        >
          {stats.offline !== undefined && (
            <div className="flex flex-col items-center">
              <span className="text-sm font-semibold text-slate-900">{stats.offline}</span>
              <span className="text-[10px] text-slate-400 font-medium uppercase tracking-wider mt-1">Offline</span>
            </div>
          )}
          <div className="flex flex-col items-center">
            <span className="text-sm font-semibold text-slate-900">{stats.normal}</span>
            <span className="text-[10px] text-green-500 font-medium uppercase tracking-wider mt-1">Normal</span>
          </div>
          <div className="flex flex-col items-center">
            <span className="text-sm font-semibold text-slate-900">{stats.warning}</span>
            <span className="text-[10px] text-orange-500 font-medium uppercase tracking-wider mt-1">Warning</span>
          </div>
          <div className="flex flex-col items-center">
            <span className="text-sm font-semibold text-slate-900">{stats.critical}</span>
            <span className="text-[10px] text-primary font-medium uppercase tracking-wider mt-1">Critical</span>
          </div>
        </button>
      </div>

      {/* Tools */}
      <div className="bg-surface rounded-lg border border-surface-border shadow-md flex items-center p-1.5 gap-1 pointer-events-auto relative" ref={menuRef}>
        <button className="p-2 rounded-md hover:bg-base-dark transition-colors relative text-surface-muted hover:text-slate-900">
          <Bell className="w-5 h-5" />
          {stats.critical > 0 && (
            <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-primary rounded-full animate-pulse border-2 border-surface"></span>
          )}
        </button>
        
        <div className="w-px h-6 bg-surface-border mx-1"></div>
        
        <button 
          className={`p-2 rounded-md transition-colors ${menuOpen ? 'bg-base-dark text-slate-900' : 'text-surface-muted hover:bg-base-dark hover:text-slate-900'}`}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <Settings className="w-5 h-5" />
        </button>

        {menuOpen && (
          <div className="absolute top-full right-0 mt-2 w-56 bg-surface rounded-lg shadow-xl border border-surface-border overflow-hidden py-2 z-[2000] animate-in fade-in zoom-in-95 duration-200">
            <div className="px-4 py-2 text-xs font-semibold text-surface-muted uppercase tracking-wider mb-1">
              Settings
            </div>
            
            <div className="px-1 space-y-1">
              {navItems.map((item, idx) => (
                <button 
                  key={idx}
                  onClick={() => {
                    setMenuOpen(false);
                    onOpenModal(item.action);
                  }} 
                  className="w-full flex items-center gap-3 px-3 py-2 text-sm text-slate-700 hover:bg-base-dark hover:text-slate-900 rounded-md transition-colors text-left"
                >
                  <span className="text-surface-muted">{item.icon}</span>
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
            
            <div className="h-px bg-surface-border my-2 mx-2"></div>
            
            <div className="px-1">
              <button 
                onClick={handleLogout} 
                className="w-full flex items-center gap-3 px-3 py-2 text-sm text-primary hover:bg-primary/10 rounded-md transition-colors"
              >
                <LogOut className="w-4 h-4" />
                <span>Disconnect</span>
              </button>
            </div>
          </div>
        )}
      </div>

    </div>
  );
}
