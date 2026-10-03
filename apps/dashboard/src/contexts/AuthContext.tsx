import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { ReactNode } from 'react';

export interface User {
  id: number;
  username: string;
  email: string;
  role: 'admin' | 'responder' | 'viewer';
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isAdmin: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    try {
      const res = await fetch('/auth/session');
      if (res.ok) {
        const data = await res.json();
        setUser({ id: data.id, username: data.username, email: data.email, role: data.role });
      } else {
        setUser(null);
      }
    } catch {
      setUser(null);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const login = useCallback(async () => {
    await refreshUser();
  }, [refreshUser]);

  const logout = useCallback(async () => {
    try {
      await fetch('/auth/logout', { method: 'POST', headers: { 'Accept': 'application/json' } });
    } catch (err) {
      console.error('Logout failed', err);
    }
    setUser(null);
  }, []);

  useEffect(() => {
    refreshUser();
  }, [refreshUser]);

  return (
    <AuthContext.Provider value={{
      user,
      isAuthenticated: !!user,
      isLoading,
      isAdmin: user?.role === 'admin',
      login,
      logout,
      refreshUser,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
