import { useState, useRef, useEffect } from 'react';
import { Search, Bell, Settings, Activity, Server, FileText, Download, BarChart2, LogOut } from 'lucide-react';

interface Stats {
  total: number;
  normal: number;
  warning: number;
  critical: number;
}

interface FloatingTopBarProps {
  onSearch: (id: string) => void;
  stats: Stats;
}

export function FloatingTopBar({ onSearch, stats }: FloatingTopBarProps) {
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
    { icon: <Server className="w-3.5 h-3.5" />, label: "Devices", href: "/protected/devices.html" },
    { icon: <BarChart2 className="w-3.5 h-3.5" />, label: "Sensor Analytics", href: "/protected/analytics.html" },
    { icon: <Activity className="w-3.5 h-3.5" />, label: "System Analytics", href: "/protected/system-analytics.html" },
    { icon: <FileText className="w-3.5 h-3.5" />, label: "Incident Logs", href: "/protected/incident-logs.html" },
    { icon: <Download className="w-3.5 h-3.5" />, label: "Export Data", href: "/protected/export.html" },
  ];

  return (
    <div className="absolute top-6 left-6 right-6 z-[1000] flex justify-between items-start pointer-events-none">
      
      {/* Brand & Search */}
      <div className="flex flex-col gap-4 pointer-events-auto">
        <div className="bg-white/40 backdrop-blur-2xl px-6 py-4 rounded-none border border-white/60 shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] flex items-center gap-6">
          <div className="w-6 h-px bg-black"></div>
          <div>
            <h1 className="font-light text-black text-xs tracking-[0.2em] uppercase">FireMonitor</h1>
            <p className="text-[9px] text-gray-600 font-normal uppercase tracking-widest mt-1">Platform</p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="bg-white/40 backdrop-blur-2xl rounded-none border border-white/60 shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] flex items-center overflow-hidden w-80 transition-all focus-within:bg-white/60">
          <div className="pl-5 py-3 text-gray-500">
            <Search className="w-3.5 h-3.5" strokeWidth={1.5} />
          </div>
          <input 
            type="text" 
            placeholder="Search Node ID..." 
            className="w-full py-3 px-4 bg-transparent outline-none text-xs font-light text-black placeholder:text-gray-500 tracking-wide rounded-none"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </form>
      </div>

      {/* Live Stats */}
      <div className="bg-white/40 backdrop-blur-2xl rounded-none border border-white/60 shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] flex items-center px-8 py-5 gap-10 pointer-events-auto">
        <div className="flex flex-col items-start border-l border-black pl-4">
          <span className="text-xl font-light text-black leading-none">{stats.total}</span>
          <span className="text-[9px] text-gray-600 font-normal uppercase tracking-widest mt-2">Active</span>
        </div>
        
        <div className="w-px h-8 bg-gray-300/50"></div>
        
        <div className="flex gap-8">
          <div className="flex flex-col items-start border-l border-green-500/50 pl-3">
            <span className="text-sm font-light text-black leading-none">{stats.normal}</span>
            <span className="text-[8px] text-gray-500 font-normal uppercase tracking-widest mt-2">Normal</span>
          </div>
          <div className="flex flex-col items-start border-l border-orange-500/50 pl-3">
            <span className="text-sm font-light text-black leading-none">{stats.warning}</span>
            <span className="text-[8px] text-gray-500 font-normal uppercase tracking-widest mt-2">Warning</span>
          </div>
          <div className="flex flex-col items-start border-l border-red-500/50 pl-3">
            <span className="text-sm font-light text-black leading-none">{stats.critical}</span>
            <span className="text-[8px] text-gray-500 font-normal uppercase tracking-widest mt-2">Critical</span>
          </div>
        </div>
      </div>

      {/* Tools */}
      <div className="bg-white/40 backdrop-blur-2xl rounded-none border border-white/60 shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] flex items-center p-2 gap-2 pointer-events-auto relative" ref={menuRef}>
        <button className="p-3 hover:bg-white/50 transition-colors relative text-gray-600 hover:text-black">
          <Bell className="w-4 h-4" strokeWidth={1.5} />
          {stats.critical > 0 && (
            <span className="absolute top-2.5 right-2.5 w-1.5 h-1.5 bg-red-500 rounded-none"></span>
          )}
        </button>
        
        <div className="w-px h-6 bg-gray-300/50"></div>
        
        <button 
          className={`p-3 transition-colors ${menuOpen ? 'bg-white/50 text-black' : 'text-gray-600 hover:bg-white/50 hover:text-black'}`}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <Settings className="w-4 h-4" strokeWidth={1.5} />
        </button>

        {menuOpen && (
          <div className="absolute top-full right-0 mt-4 w-56 bg-white/70 backdrop-blur-3xl rounded-none shadow-[0_12px_40px_0_rgba(31,38,135,0.1)] border border-white/80 overflow-hidden py-4 z-[2000] animate-in fade-in slide-in-from-top-4 duration-500">
            <div className="px-5 py-2 text-[9px] font-normal text-gray-400 uppercase tracking-widest mb-2">
              Menu
            </div>
            
            <div className="px-2 space-y-1">
              {navItems.map((item, idx) => (
                <a 
                  key={idx}
                  href={item.href} 
                  className="flex items-center gap-4 px-4 py-3 text-xs text-gray-700 hover:bg-white/60 hover:text-black transition-colors font-light tracking-wide"
                >
                  <span className="text-gray-400">{item.icon}</span>
                  <span>{item.label}</span>
                </a>
              ))}
            </div>
            
            <div className="h-px bg-gray-200/50 my-3 mx-4"></div>
            
            <div className="px-2">
              <button 
                onClick={handleLogout} 
                className="w-full flex items-center gap-4 px-4 py-3 text-xs text-red-600 hover:bg-red-50/50 transition-colors font-light tracking-wide"
              >
                <LogOut className="w-3.5 h-3.5" strokeWidth={1.5} />
                <span>Disconnect</span>
              </button>
            </div>
          </div>
        )}
      </div>

    </div>
  );
}
