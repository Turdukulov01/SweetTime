'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { requestSmsCode, verifySmsCode } from '@/lib/api';
import { useAuth } from '@/context/AuthContext';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

export function PhoneSmsForm({ extraFields }: { extraFields?: React.ReactNode }) {
  const router = useRouter();
  const { login } = useAuth();
  const [phone, setPhone] = useState('+996 ');
  const [step, setStep] = useState<'phone' | 'code'>('phone');
  const [code, setCode] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleRequestCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);
    await requestSmsCode(phone);
    setIsSubmitting(false);
    setStep('code');
  }

  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);
    const result = await verifySmsCode(phone, code);
    setIsSubmitting(false);
    if (result.success) {
      await login();
      router.push('/profile');
    } else {
      setError('Неверный код. Попробуйте ещё раз (подсказка: 0000)');
    }
  }

  if (step === 'phone') {
    return (
      <form onSubmit={handleRequestCode} className="space-y-4">
        {extraFields}
        <Input
          label="Номер телефона"
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="+996 700 123 456"
          required
        />
        <Button type="submit" fullWidth isLoading={isSubmitting}>
          Получить код
        </Button>
      </form>
    );
  }

  return (
    <motion.form
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      onSubmit={handleVerify}
      className="space-y-4"
    >
      <p className="text-sm text-ink-muted">
        Код отправлен на <span className="font-semibold text-ink dark:text-cream">{phone}</span>
      </p>
      <Input
        label="Код из SMS"
        inputMode="numeric"
        maxLength={4}
        value={code}
        onChange={(e) => setCode(e.target.value)}
        placeholder="0000"
        error={error ?? undefined}
        required
      />
      <Button type="submit" fullWidth isLoading={isSubmitting}>
        Подтвердить
      </Button>
      <button
        type="button"
        onClick={() => setStep('phone')}
        className="w-full text-center text-sm text-ink-muted hover:text-berry-500"
      >
        Изменить номер
      </button>
    </motion.form>
  );
}
