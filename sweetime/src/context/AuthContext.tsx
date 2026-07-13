'use client';

import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import type { User } from '@/types';
import { fetchCurrentUser } from '@/lib/api';

const STORAGE_KEY = 'sweetime:session';

interface AuthContextValue {
  user: User | null;
  isLoading: boolean;
  login: () => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const hasSession = typeof window !== 'undefined' && localStorage.getItem(STORAGE_KEY) === '1';
    if (hasSession) {
      fetchCurrentUser()
        .then(setUser)
        .finally(() => setIsLoading(false));
    } else {
      setIsLoading(false);
    }
  }, []);

  const login = useCallback(async () => {
    const currentUser = await fetchCurrentUser();
    setUser(currentUser);
    localStorage.setItem(STORAGE_KEY, '1');
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem(STORAGE_KEY);
  }, []);

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
