import Link from 'next/link';
import { SITE } from '@/lib/constants';
import { Card } from '@/components/ui/Card';

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
}) {
  return (
    <div className="relative flex min-h-[70vh] items-center justify-center overflow-hidden py-16">
      <div className="pointer-events-none absolute -left-16 -top-16 h-56 w-56 rounded-blob bg-pink-200/50 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-16 -right-16 h-56 w-56 rounded-blob bg-mint-200/50 blur-3xl" />

      <div className="relative w-full max-w-md px-4">
        <Link href="/" className="mb-6 flex items-center justify-center gap-2">
          <span className="flex h-9 w-9 items-center justify-center rounded-blob bg-pink-300 text-lg">
            🧋
          </span>
          <span className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
            {SITE.name}
          </span>
        </Link>
        <Card>
          <h1 className="font-display text-2xl font-semibold text-berry-500 dark:text-cream">
            {title}
          </h1>
          {subtitle && <p className="mt-1 text-sm text-ink-muted">{subtitle}</p>}
          <div className="mt-6">{children}</div>
        </Card>
        {footer && <div className="mt-5 text-center text-sm text-ink-muted">{footer}</div>}
      </div>
    </div>
  );
}
