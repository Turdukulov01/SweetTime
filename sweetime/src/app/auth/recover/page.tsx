'use client';

import { useState } from 'react';
import { CheckCircle2 } from 'lucide-react';
import { AuthShell } from '@/components/auth/AuthShell';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { requestSmsCode } from '@/lib/api';

export default function RecoverPasswordPage() {
  const [phone, setPhone] = useState('+996 ');
  const [sent, setSent] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setIsSubmitting(true);
    await requestSmsCode(phone);
    setIsSubmitting(false);
    setSent(true);
  }

  return (
    <AuthShell title="Восстановление доступа" subtitle="Пришлём код для сброса пароля по SMS">
      {sent ? (
        <div className="flex flex-col items-center gap-3 py-4 text-center">
          <CheckCircle2 className="h-12 w-12 text-mint-500" />
          <p className="text-ink-muted">
            Код отправлен на <span className="font-semibold text-ink dark:text-cream">{phone}</span>.
            Проверьте SMS и следуйте инструкциям.
          </p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input
            label="Номер телефона"
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            required
          />
          <Button type="submit" fullWidth isLoading={isSubmitting}>
            Отправить код
          </Button>
        </form>
      )}
    </AuthShell>
  );
}
