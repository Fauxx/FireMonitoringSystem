import { useState } from 'react';
import { Loader2 } from 'lucide-react';

interface LoginOverlayProps {
  onLoginSuccess: () => void;
}

export function LoginOverlay({ onLoginSuccess }: LoginOverlayProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: username, password })
      });

      if (res.ok) {
        onLoginSuccess();
      } else {
        const data = await res.json();
        setError(data.error || 'Invalid credentials');
      }
    } catch (err) {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="absolute inset-0 z-[2000] flex items-center justify-center bg-white/10 backdrop-blur-md">
      <div className="bg-white/40 backdrop-blur-2xl rounded-none shadow-2xl border border-white/60 p-12 w-[420px] animate-in fade-in duration-700">
        
        <div className="mb-12">
          <div className="w-10 h-[1px] bg-black mb-6"></div>
          <h1 className="text-3xl font-light text-black tracking-widest uppercase">FireMonitor</h1>
          <p className="text-xs text-gray-600 font-normal mt-2 tracking-widest uppercase">System Access</p>
        </div>

        {error && (
          <div className="text-red-500 text-xs font-medium mb-6 border-l border-red-500 pl-3 py-1">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-6">
          <div className="relative">
            <input 
              type="text" 
              required
              className="w-full pb-2 bg-transparent border-b border-gray-400/50 outline-none focus:border-black transition-colors text-sm font-light text-black placeholder:text-gray-500 rounded-none"
              placeholder="Identification"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>

          <div className="relative">
            <input 
              type="password" 
              required
              className="w-full pb-2 bg-transparent border-b border-gray-400/50 outline-none focus:border-black transition-colors text-sm font-light text-black placeholder:text-gray-500 rounded-none"
              placeholder="Passcode"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <button 
            type="submit" 
            disabled={loading}
            className="w-full bg-transparent hover:bg-black text-black hover:text-white border border-black font-light text-sm tracking-widest uppercase py-4 transition-all duration-300 flex justify-center items-center mt-8 rounded-none"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : 'Authenticate'}
          </button>
        </form>
        
      </div>
    </div>
  );
}
