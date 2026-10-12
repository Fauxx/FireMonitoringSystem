import React, { useState } from 'react';
import { ModalOverlay } from './ModalOverlay';
import { 
  User, Mail, Shield, Lock, Building, Phone, 
  Bell, Volume2, Compass, CheckCircle2, Copy, 
  Save, Eye, EyeOff, Laptop, MapPin
} from 'lucide-react';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ProfileModal({ isOpen, onClose }: ProfileModalProps) {
  const [activeTab, setActiveTab] = useState<'general' | 'security' | 'preferences'>('general');
  const [copiedToken, setCopiedToken] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Form states (placeholders)
  const [name, setName] = useState('Alex Vance');
  const [email, setEmail] = useState('ops-lead@fireops.local');
  const [phone, setPhone] = useState('+63 (047) 252-4000');
  const [station, setStation] = useState('Sector 4 Command Post (Subic / Olongapo)');
  const [org, setOrg] = useState('Municipal Fire & Rescue Command');

  // Preferences states
  const [soundAlerts, setSoundAlerts] = useState(true);
  const [autoPan, setAutoPan] = useState(true);
  const [refreshRate, setRefreshRate] = useState('3');
  const [mapStyle, setMapStyle] = useState('dark');

  if (!isOpen) return null;

  const handleCopyToken = () => {
    navigator.clipboard?.writeText('fops_live_99a8b12e4f0c789d31ac4e82');
    setCopiedToken(true);
    setTimeout(() => setCopiedToken(false), 2000);
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 3000);
  };

  return (
    <ModalOverlay
      title="User Profile & Security Settings"
      subtitle="Operator account details, access credentials, and station preferences"
      icon={<User className="w-5 h-5 text-primary" />}
      onClose={onClose}
      width="max-w-4xl"
    >
      <div className="bg-slate-50 flex flex-col h-[650px] overflow-hidden">
        
        {/* Profile Identity Card */}
        <div className="bg-white px-6 py-5 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shrink-0">
          <div className="flex items-center gap-4">
            <div className="relative">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-primary to-orange-500 text-white flex items-center justify-center font-bold text-xl shadow-md border-2 border-white">
                AV
              </div>
              <span className="absolute -bottom-1 -right-1 w-4 h-4 rounded-full bg-emerald-500 border-2 border-white" title="Session Active"></span>
            </div>

            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-bold text-slate-900 text-lg leading-tight">{name}</h3>
                <span className="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-primary/10 text-primary border border-primary/20">
                  Administrator
                </span>
              </div>
              <p className="text-xs text-slate-500 font-medium mt-0.5 flex items-center gap-2">
                <span>{email}</span>
                <span>•</span>
                <span className="flex items-center gap-1 text-slate-600">
                  <MapPin className="w-3 h-3 text-slate-400" />
                  Sector 4 Operations
                </span>
              </p>
            </div>
          </div>

          {/* Tab Navigation */}
          <div className="flex items-center bg-slate-100 p-1 rounded-xl border border-slate-200 self-start sm:self-center">
            <button
              onClick={() => setActiveTab('general')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                activeTab === 'general' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              General Info
            </button>
            <button
              onClick={() => setActiveTab('security')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                activeTab === 'security' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Security & Auth
            </button>
            <button
              onClick={() => setActiveTab('preferences')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                activeTab === 'preferences' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Preferences
            </button>
          </div>
        </div>

        {/* Success Alert Banner */}
        {savedSuccess && (
          <div className="bg-emerald-50 border-b border-emerald-200 px-6 py-2.5 flex items-center gap-2 text-xs font-semibold text-emerald-800 animate-in fade-in duration-200 shrink-0">
            <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
            <span>Profile settings saved successfully. (Placeholder mock saved)</span>
          </div>
        )}

        {/* Tab Content Area */}
        <div className="flex-1 p-6 overflow-y-auto">
          {activeTab === 'general' && (
            <div className="max-w-2xl mx-auto space-y-5">
              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <User className="w-3.5 h-3.5 text-primary" />
                  Personal Information
                </h4>
                
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Full Name</label>
                    <input 
                      type="text" 
                      value={name} 
                      onChange={(e) => setName(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Username</label>
                    <input 
                      type="text" 
                      value="admin" 
                      disabled
                      className="w-full px-3 py-2 text-sm bg-slate-100 border border-slate-200 rounded-lg text-slate-500 font-mono cursor-not-allowed"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Email Address</label>
                    <div className="relative">
                      <input 
                        type="email" 
                        value={email} 
                        onChange={(e) => setEmail(e.target.value)}
                        className="w-full pl-9 pr-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                      />
                      <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Duty Phone / Dispatch</label>
                    <div className="relative">
                      <input 
                        type="text" 
                        value={phone} 
                        onChange={(e) => setPhone(e.target.value)}
                        className="w-full pl-9 pr-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                      />
                      <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <Building className="w-3.5 h-3.5 text-primary" />
                  Organization & Station Assignment
                </h4>
                
                <div className="space-y-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Command Agency</label>
                    <input 
                      type="text" 
                      value={org} 
                      onChange={(e) => setOrg(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Assigned Station / Post</label>
                    <input 
                      type="text" 
                      value={station} 
                      onChange={(e) => setStation(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                    />
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'security' && (
            <div className="max-w-2xl mx-auto space-y-5">
              {/* Credentials & Active Session */}
              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <Shield className="w-3.5 h-3.5 text-emerald-600" />
                  Authentication Status
                </h4>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="p-3.5 rounded-lg bg-emerald-50/60 border border-emerald-200/80">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-bold text-emerald-900">Two-Factor Authentication</span>
                      <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-600 text-white">Active</span>
                    </div>
                    <p className="text-[11px] text-emerald-700">Hardware token (TOTP) verified for this session.</p>
                  </div>

                  <div className="p-3.5 rounded-lg bg-slate-50 border border-slate-200">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-bold text-slate-800">Session Cookie</span>
                      <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-200 text-slate-700">HTTP-Only</span>
                    </div>
                    <p className="text-[11px] text-slate-500">SameSite strict cookie with automatic refresh.</p>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">API Ingest Token</label>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 px-3 py-2 text-xs font-mono bg-slate-100 border border-slate-200 rounded-lg text-slate-600 truncate">
                      fops_live_99a8b12e4f0c789d31ac4e82
                    </div>
                    <button
                      type="button"
                      onClick={handleCopyToken}
                      className="px-3 py-2 bg-slate-100 hover:bg-slate-200 border border-slate-300 rounded-lg text-xs font-semibold text-slate-700 flex items-center gap-1.5 cursor-pointer transition-colors shrink-0"
                    >
                      {copiedToken ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                      <span>{copiedToken ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Password Change Placeholder */}
              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <Lock className="w-3.5 h-3.5 text-primary" />
                  Change Password (Placeholder)
                </h4>

                <div className="space-y-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Current Password</label>
                    <div className="relative">
                      <input 
                        type={showPassword ? "text" : "password"} 
                        placeholder="••••••••••••"
                        className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      >
                        {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-semibold text-slate-700 mb-1">New Password</label>
                      <input 
                        type={showPassword ? "text" : "password"} 
                        placeholder="••••••••••••"
                        className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-slate-700 mb-1">Confirm New Password</label>
                      <input 
                        type={showPassword ? "text" : "password"} 
                        placeholder="••••••••••••"
                        className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'preferences' && (
            <div className="max-w-2xl mx-auto space-y-5">
              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <Bell className="w-3.5 h-3.5 text-primary" />
                  Tactical Alerts & Sound
                </h4>

                <div className="space-y-3">
                  <label className="flex items-center justify-between p-3 rounded-lg border border-slate-200 bg-slate-50/50 hover:bg-slate-50 cursor-pointer transition-colors">
                    <div className="flex items-center gap-3">
                      <Volume2 className="w-4 h-4 text-primary" />
                      <div>
                        <div className="text-xs font-bold text-slate-800">Critical Alarm Chime</div>
                        <div className="text-[11px] text-slate-500">Play emergency audio signal when node reports Critical status</div>
                      </div>
                    </div>
                    <input 
                      type="checkbox" 
                      checked={soundAlerts} 
                      onChange={(e) => setSoundAlerts(e.target.checked)}
                      className="w-4 h-4 text-primary rounded border-slate-300 focus:ring-primary cursor-pointer"
                    />
                  </label>

                  <label className="flex items-center justify-between p-3 rounded-lg border border-slate-200 bg-slate-50/50 hover:bg-slate-50 cursor-pointer transition-colors">
                    <div className="flex items-center gap-3">
                      <Compass className="w-4 h-4 text-primary" />
                      <div>
                        <div className="text-xs font-bold text-slate-800">Auto-Fly Camera on Incident</div>
                        <div className="text-[11px] text-slate-500">Automatically pan 3D map viewport to highest hazard anomaly</div>
                      </div>
                    </div>
                    <input 
                      type="checkbox" 
                      checked={autoPan} 
                      onChange={(e) => setAutoPan(e.target.checked)}
                      className="w-4 h-4 text-primary rounded border-slate-300 focus:ring-primary cursor-pointer"
                    />
                  </label>
                </div>
              </div>

              <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-xs space-y-4">
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                  <Laptop className="w-3.5 h-3.5 text-primary" />
                  Display & Refresh Settings
                </h4>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Telemetry Polling Rate</label>
                    <select
                      value={refreshRate}
                      onChange={(e) => setRefreshRate(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-800 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary cursor-pointer"
                    >
                      <option value="1">1 second (High Load / Real-time)</option>
                      <option value="3">3 seconds (Recommended Tactical)</option>
                      <option value="5">5 seconds (Standard)</option>
                      <option value="10">10 seconds (Low Bandwidth)</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Tactical Map Basemap</label>
                    <select
                      value={mapStyle}
                      onChange={(e) => setMapStyle(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-300 rounded-lg text-slate-800 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary cursor-pointer"
                    >
                      <option value="dark">Carto Dark Matter (Night Ops)</option>
                      <option value="positron">Carto Positron (Daylight Ops)</option>
                      <option value="satellite">Satellite Imagery Overlay</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 border-t border-slate-200 bg-white flex items-center justify-between shrink-0">
          <span className="text-xs text-slate-400 font-medium">
            Role: <span className="text-slate-700 font-semibold">FireOps Administrator (Placeholder Mode)</span>
          </span>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSave}
              className="px-5 py-2 rounded-xl bg-primary text-white text-xs font-bold hover:bg-primary-dark transition-all flex items-center gap-2 shadow-sm cursor-pointer"
            >
              <Save className="w-3.5 h-3.5" />
              <span>Save Settings</span>
            </button>
          </div>
        </div>

      </div>
    </ModalOverlay>
  );
}
