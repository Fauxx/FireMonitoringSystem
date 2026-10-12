import { useState, useRef, useEffect } from 'react';
import { Search, Bell, Settings, Activity, Server, FileText, Download, BarChart2, LogOut, User, Sliders, ChevronRight } from 'lucide-react';

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

      {/* Live Device Overview */}
      <div className="bg-surface rounded-lg border border-surface-border shadow-md flex items-center px-4 py-2 gap-3 pointer-events-auto">
        <button 
          onClick={() => onOpenModal('devices')}
          className="flex flex-col items-center px-2 py-1 rounded-md hover:bg-base-dark transition-colors cursor-pointer group"
          title="View All Registered Devices"
        >
          <span className="text-lg font-bold text-slate-900 group-hover:text-primary transition-colors">{stats.total}</span>
          <span className="text-[10px] text-surface-muted font-medium uppercase tracking-wider">Total</span>
        </button>
        
        <div className="w-px h-7 bg-surface-border"></div>
        
        <div className="flex items-center gap-1.5">
          {stats.offline !== undefined && (
            <button 
              onClick={() => onOpenModal('devices')}
              className="flex flex-col items-center px-2 py-1 rounded-md hover:bg-base-dark transition-colors cursor-pointer"
              title="View Offline Nodes (No telemetry for >15m)"
            >
              <div className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-slate-400"></span>
                <span className="text-xs font-semibold text-slate-700">{stats.offline}</span>
              </div>
              <span className="text-[9px] text-slate-400 font-medium uppercase tracking-wider mt-0.5">Offline</span>
            </button>
          )}

          <button 
            onClick={() => onOpenModal('devices')}
            className="flex flex-col items-center px-2 py-1 rounded-md hover:bg-base-dark transition-colors cursor-pointer"
            title="View Normal Nodes"
          >
            <div className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              <span className="text-xs font-semibold text-slate-800">{stats.normal}</span>
            </div>
            <span className="text-[9px] text-emerald-600 font-medium uppercase tracking-wider mt-0.5">Normal</span>
          </button>

          <button 
            onClick={() => onOpenModal('alerts')}
            className={`flex flex-col items-center px-2 py-1 rounded-md transition-colors cursor-pointer ${stats.warning > 0 ? 'bg-orange-50 border border-orange-200' : 'hover:bg-base-dark'}`}
            title="View Warning Alerts"
          >
            <div className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-orange-500"></span>
              <span className={`text-xs font-semibold ${stats.warning > 0 ? 'text-orange-700' : 'text-slate-800'}`}>{stats.warning}</span>
            </div>
            <span className="text-[9px] text-orange-600 font-medium uppercase tracking-wider mt-0.5">Warning</span>
          </button>

          <button 
            onClick={() => onOpenModal('alerts')}
            className={`flex flex-col items-center px-2 py-1 rounded-md transition-colors cursor-pointer ${stats.critical > 0 ? 'bg-primary/10 border border-primary/30 animate-pulse' : 'hover:bg-base-dark'}`}
            title="View Critical Fire Alerts"
          >
            <div className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-primary"></span>
              <span className={`text-xs font-bold ${stats.critical > 0 ? 'text-primary' : 'text-slate-800'}`}>{stats.critical}</span>
            </div>
            <span className="text-[9px] text-primary font-bold uppercase tracking-wider mt-0.5">Critical</span>
          </button>
        </div>
      </div>

      {/* Tools */}
      <div className="bg-surface rounded-lg border border-surface-border shadow-md flex items-center p-1.5 gap-1 pointer-events-auto relative" ref={menuRef}>
        <button 
          onClick={() => onOpenModal('alerts')}
          className="p-2 rounded-md hover:bg-base-dark transition-colors relative text-surface-muted hover:text-slate-900 cursor-pointer"
          title="View Alerts"
        >
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
          <div className="absolute top-full right-0 mt-2 w-64 bg-surface rounded-xl shadow-2xl border border-surface-border overflow-hidden py-2 z-[2000] animate-in fade-in zoom-in-95 duration-200">
            {/* Profile Settings Button */}
            <div className="px-2 pb-1.5">
              <button
                onClick={() => {
                  setMenuOpen(false);
                  onOpenModal('profile');
                }}
                className="w-full flex items-center gap-3 p-2.5 rounded-lg bg-slate-50 hover:bg-slate-100 border border-slate-200 text-left transition-all group cursor-pointer"
                title="Open Profile Settings"
              >
                <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs shrink-0 group-hover:scale-105 transition-transform">
                  <User className="w-4 h-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-xs font-bold text-slate-800 truncate">Alex Vance</div>
                  <div className="text-[10px] text-slate-500 font-medium truncate">Profile Settings</div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-0.5 transition-transform shrink-0" />
              </button>
            </div>

            {/* Command Center Primary Hub Button */}
            <div className="px-2 pb-2">
              <button
                onClick={() => {
                  setMenuOpen(false);
                  onOpenModal('command-center');
                }}
                className="w-full flex items-center gap-3 p-2.5 rounded-lg bg-primary text-white hover:bg-primary-dark transition-all shadow-sm group cursor-pointer"
                title="Launch Command Center Hub"
              >
                <Sliders className="w-4 h-4 text-white shrink-0 group-hover:rotate-45 transition-transform" />
                <div className="flex-1 min-w-0 text-left">
                  <div className="text-xs font-bold truncate">Command Center</div>
                  <div className="text-[10px] text-white/80 truncate">Unified Fleet & Ops Hub</div>
                </div>
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-white/20 font-mono font-bold">Open</span>
              </button>
            </div>

            <div className="h-px bg-surface-border my-1 mx-2"></div>

            <div className="px-4 py-1 text-[10px] font-bold text-surface-muted uppercase tracking-wider">
              Workstation Views
            </div>
            
            <div className="px-1 space-y-0.5">
              {navItems.map((item, idx) => (
                <button 
                  key={idx}
                  onClick={() => {
                    setMenuOpen(false);
                    onOpenModal(item.action);
                  }} 
                  className="w-full flex items-center gap-3 px-3 py-1.5 text-xs text-slate-700 hover:bg-base-dark hover:text-slate-900 rounded-md transition-colors text-left font-medium cursor-pointer"
                >
                  <span className="text-surface-muted">{item.icon}</span>
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
            
            <div className="h-px bg-surface-border my-1.5 mx-2"></div>
            
            <div className="px-1">
              <button 
                onClick={handleLogout} 
                className="w-full flex items-center gap-3 px-3 py-2 text-xs font-semibold text-primary hover:bg-primary/10 rounded-md transition-colors cursor-pointer"
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
