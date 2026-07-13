'use client';

import { useState } from 'react';
import Link from 'next/link';
import { AuthShell } from '@/components/auth/AuthShell';
import { PhoneSmsForm } from '@/components/auth/PhoneSmsForm';
import { SocialButtons } from '@/components/auth/SocialButtons';
import { Input } from '@/components/ui/Input';

export default function RegisterPage() {
  const [name, setName] = useState('');

  return (
    <AuthShell
      title="Создать аккаунт"
      subtitle="Регистрация займёт меньше минуты"
      footer={
        <>
          Уже с нами?{' '}
          <Link href="/auth/login" className="font-semibold text-berry-500 hover:underline dark:text-cream">
            Войти
          </Link>
        </>
      }
    >
      <div className="space-y-5">
        <SocialButtons />
        <div className="flex items-center gap-3 text-xs uppercase tracking-wide text-ink-muted">
          <span className="h-px flex-1 bg-pink-100" /> или по телефону{' '}
          <span className="h-px flex-1 bg-pink-100" />
        </div>
        <PhoneSmsForm
          extraFields={
            <Input
              label="Имя"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Как к вам обращаться?"
              required
            />
          }
        />
        <p className="text-center text-xs text-ink-muted">
          Регистрируясь, вы соглашаетесь с{' '}
          <Link href="/terms" className="underline">
            условиями использования
          </Link>
        </p>
      </div>
    </AuthShell>
  );
}
