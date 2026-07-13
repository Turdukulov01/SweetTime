'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Moon, Sun } from 'lucide-react';
import type { User } from '@/types';
import { useAuth } from '@/context/AuthContext';
import { useTheme } from '@/context/ThemeContext';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

export function SettingsForm({ user }: { user: User }) {
  const router = useRouter();
  const { logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const [name, setName] = useState(user.name);
  const [email, setEmail] = useState(user.email ?? '');
  const [notifyPromo, setNotifyPromo] = useState(true);
  const [saved, setSaved] = useState(false);

  function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  function handleLogout() {
    logout();
    router.push('/');
  }

  return (
    <div className="space-y-6">
      <form onSubmit={handleSave} className="space-y-4">
        <Input label="Имя" value={name} onChange={(e) => setName(e.target.value)} />
        <Input label="Телефон" value={user.phone} disabled />
        <Input
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
        />
        <label className="flex items-center justify-between rounded-2xl bg-pink-50 px-4 py-3 text-sm dark:bg-berry-600/40">
          <span>Присылать акции и промокоды</span>
          <input
            type="checkbox"
            checked={notifyPromo}
            onChange={(e) => setNotifyPromo(e.target.checked)}
            className="h-5 w-5 accent-berry-500"
          />
        </label>
        <Button type="submit">{saved ? 'Сохранено ✓' : 'Сохранить изменения'}</Button>
      </form>

      <div className="flex items-center justify-between rounded-2xl border-2 border-pink-100 px-4 py-3 dark:border-berry-300/20">
        <span className="text-sm font-medium">Тема оформления</span>
        <button
          onClick={toggleTheme}
          className="flex items-center gap-2 rounded-pearl bg-pink-100 px-3 py-1.5 text-sm font-medium text-berry-600 dark:bg-berry-600/60 dark:text-cream"
        >
          {theme === 'light' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          {theme === 'light' ? 'Светлая' : 'Тёмная'}
        </button>
      </div>

      <Button variant="danger" onClick={handleLogout}>
        Выйти из аккаунта
      </Button>
    </div>
  );
}
