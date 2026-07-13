'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { loginWithProvider } from '@/lib/api';
import { useAuth } from '@/context/AuthContext';
import { Button } from '@/components/ui/Button';

function GoogleIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden>
      <path
        fill="#EA4335"
        d="M12 10.2v3.9h5.5c-.24 1.3-1.66 3.8-5.5 3.8-3.31 0-6-2.74-6-6.1s2.69-6.1 6-6.1c1.88 0 3.14.8 3.86 1.49l2.63-2.53C16.9 2.9 14.7 2 12 2 6.98 2 2.9 6.06 2.9 11s4.08 9 9.1 9c5.25 0 8.74-3.69 8.74-8.89 0-.6-.07-1.06-.15-1.51H12Z"
      />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5 fill-current" aria-hidden>
      <path d="M16.36 1.43c0 1.14-.42 2.2-1.25 3.02-.99.98-2.2 1.55-3.4 1.46-.13-1.1.42-2.28 1.24-3.06.87-.85 2.35-1.5 3.41-1.42ZM20 17.1c-.55 1.27-.81 1.83-1.52 2.95-.99 1.56-2.39 3.51-4.13 3.53-1.54.02-1.94-1-4.03-.99-2.1.01-2.53 1.01-4.07.99-1.74-.02-3.06-1.77-4.05-3.32C-.42 16.7-.63 12 1.63 9.5c1.1-1.23 2.75-2.02 4.25-2.04 1.55-.03 2.4 1.03 4.02 1.03 1.62 0 2.36-1.03 4.02-1 .68.03 2.6.28 3.83 2.1-.1.06-2.29 1.34-2.27 4 .02 3.18 2.79 4.24 2.52 4.51Z" />
    </svg>
  );
}

export function SocialButtons() {
  const router = useRouter();
  const { login } = useAuth();
  const [loading, setLoading] = useState<'google' | 'apple' | null>(null);

  async function handleLogin(provider: 'google' | 'apple') {
    setLoading(provider);
    await loginWithProvider(provider);
    await login();
    router.push('/profile');
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Button
        variant="outline"
        isLoading={loading === 'google'}
        onClick={() => handleLogin('google')}
        className="!border-pink-100"
      >
        <GoogleIcon /> Google
      </Button>
      <Button
        variant="outline"
        isLoading={loading === 'apple'}
        onClick={() => handleLogin('apple')}
        className="!border-pink-100"
      >
        <AppleIcon /> Apple
      </Button>
    </div>
  );
}
