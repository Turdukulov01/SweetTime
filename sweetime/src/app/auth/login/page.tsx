import Link from 'next/link';
import { AuthShell } from '@/components/auth/AuthShell';
import { PhoneSmsForm } from '@/components/auth/PhoneSmsForm';
import { SocialButtons } from '@/components/auth/SocialButtons';

export const metadata = { title: 'Вход' };

export default function LoginPage() {
  return (
    <AuthShell
      title="С возвращением!"
      subtitle="Войдите, чтобы видеть бонусы и историю заказов"
      footer={
        <>
          Нет аккаунта?{' '}
          <Link href="/auth/register" className="font-semibold text-berry-500 hover:underline dark:text-cream">
            Зарегистрироваться
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
        <PhoneSmsForm />
        <Link
          href="/auth/recover"
          className="block text-center text-sm text-ink-muted hover:text-berry-500"
        >
          Забыли пароль?
        </Link>
      </div>
    </AuthShell>
  );
}
