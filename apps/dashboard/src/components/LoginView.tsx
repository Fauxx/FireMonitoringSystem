import React, { useState } from 'react';
import { User, Lock, Activity, AlertTriangle, Loader2, ShieldCheck } from 'lucide-react';

interface LoginViewProps {
  onLogin: () => void;
}

export function LoginView({ onLogin }: LoginViewProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch('/auth/login', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ email: username, password })
      });

      if (response.ok) {
        onLogin();
      } else {
        const data = await response.json().catch(() => ({}));
        setError(data.error || data.message || 'Invalid credentials');
      }
    } catch (err) {
      setError('Failed to connect to authentication server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-neutral-900 flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="relative bg-surface rounded-2xl shadow-2xl border border-surface-border p-8 overflow-hidden">
          {/* Top accent line */}
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-primary via-primary-light to-primary" />

          {/* Brand Header */}
          <div className="flex items-center gap-3.5 mb-8">
            <div className="w-10 h-10 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary shadow-sm">
              <Activity className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="font-semibold text-slate-900 text-lg leading-tight">FireMonitor</h1>
                <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20">Live</span>
              </div>
              <p className="text-xs text-surface-muted font-normal mt-0.5">Enterprise Early Warning & Operations</p>
            </div>
          </div>

          {/* Error notification */}
          {error && (
            <div className="flex items-center gap-2.5 bg-red-50 border border-red-200 text-red-600 text-xs px-3.5 py-3 rounded-lg mb-6 animate-in fade-in duration-150">
              <AlertTriangle className="w-4 h-4 shrink-0 text-red-500" />
              <span>{error}</span>
            </div>
          )}

          {/* Credentials Form */}
          <form className="space-y-5" onSubmit={handleSubmit}>
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider">
                Account Identifier
              </label>
              <div className="relative flex items-center">
                <div className="absolute left-3.5 text-surface-muted pointer-events-none">
                  <User className="w-4 h-4" />
                </div>
                <input
                  type="text"
                  required
                  autoFocus
                  className="w-full pl-10 pr-3.5 py-2.5 bg-base-light border border-surface-border rounded-lg text-sm text-slate-900 placeholder:text-surface-muted focus:outline-none focus:ring-2 focus:ring-primary/40 focus:border-primary transition-all"
                  placeholder="admin"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider">
                Passcode
              </label>
              <div className="relative flex items-center">
                <div className="absolute left-3.5 text-surface-muted pointer-events-none">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  type="password"
                  required
                  className="w-full pl-10 pr-3.5 py-2.5 bg-base-light border border-surface-border rounded-lg text-sm text-slate-900 placeholder:text-surface-muted focus:outline-none focus:ring-2 focus:ring-primary/40 focus:border-primary transition-all"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 px-4 bg-primary hover:bg-primary-dark text-white font-medium text-sm rounded-lg shadow-md shadow-primary/25 hover:shadow-lg hover:shadow-primary/30 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed mt-3"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Authenticating...</span>
                </>
              ) : (
                <span>Sign In to Dashboard</span>
              )}
            </button>
          </form>

          {/* Security badge footer */}
          <div className="flex items-center justify-center gap-2 text-[11px] text-surface-muted border-t border-surface-border pt-4 mt-6">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
            <span>Encrypted Session • Role-Based Access Control</span>
          </div>
        </div>
      </div>
    </div>
  );
}
