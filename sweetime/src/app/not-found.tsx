import Link from 'next/link';
import { Button } from '@/components/ui/Button';

export const metadata = { title: 'Страница не найдена' };

export default function NotFound() {
  return (
    <div className="container-sweetime flex flex-col items-center justify-center gap-5 py-32 text-center">
      <span className="text-7xl">🧋</span>
      <h1 className="font-display text-5xl font-semibold text-berry-500 dark:text-cream">404</h1>
      <p className="max-w-sm text-ink-muted">
        Кажется, этой страницы нет в меню. Но у нас точно есть что-то вкусное!
      </p>
      <Link href="/">
        <Button size="lg">На главную</Button>
      </Link>
    </div>
  );
}
