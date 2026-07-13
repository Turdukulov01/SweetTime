import Link from 'next/link';
import { Instagram, MapPin, MessageCircle, Phone } from 'lucide-react';
import { SITE } from '@/lib/constants';

const FOOTER_COLUMNS = [
  {
    title: 'Меню',
    links: [
      { href: '/catalog', label: 'Весь каталог' },
      { href: '/catalog?category=milk-tea', label: 'Милк-ти' },
      { href: '/catalog?category=coffee', label: 'Кофе' },
      { href: '/catalog?tag=new', label: 'Новинки' },
    ],
  },
  {
    title: 'Компания',
    links: [
      { href: '/about', label: 'О нас' },
      { href: '/promotions', label: 'Акции и бонусы' },
      { href: '/franchise', label: 'Франшиза' },
      { href: '/careers', label: 'Вакансии' },
    ],
  },
  {
    title: 'Помощь',
    links: [
      { href: '/delivery', label: 'Доставка и оплата' },
      { href: '/faq', label: 'Частые вопросы' },
      { href: '/profile', label: 'Личный кабинет' },
      { href: '/contacts', label: 'Контакты' },
    ],
  },
];

export function Footer() {
  return (
    <footer className="mt-24 border-t border-pink-100/70 bg-cream-soft dark:border-berry-300/20 dark:bg-berry-700">
      <div className="container-sweetime grid gap-10 py-14 sm:grid-cols-2 lg:grid-cols-5">
        <div className="lg:col-span-2">
          <Link href="/" className="flex items-center gap-2">
            <span className="flex h-9 w-9 items-center justify-center rounded-blob bg-pink-300 text-lg">
              🧋
            </span>
            <span className="font-display text-2xl font-semibold text-berry-500 dark:text-cream">
              {SITE.name}
            </span>
          </Link>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-ink-muted">
            {SITE.description}
          </p>
          <div className="mt-5 flex gap-3">
            <a
              href="#"
              aria-label="Instagram"
              className="flex h-9 w-9 items-center justify-center rounded-pearl bg-pink-100 text-berry-500 hover:bg-pink-200"
            >
              <Instagram className="h-4 w-4" />
            </a>
            <a
              href="#"
              aria-label="WhatsApp"
              className="flex h-9 w-9 items-center justify-center rounded-pearl bg-pink-100 text-berry-500 hover:bg-pink-200"
            >
              <MessageCircle className="h-4 w-4" />
            </a>
          </div>
        </div>

        {FOOTER_COLUMNS.map((col) => (
          <div key={col.title}>
            <h3 className="mb-3 font-display text-sm font-semibold uppercase tracking-wide text-berry-500 dark:text-cream">
              {col.title}
            </h3>
            <ul className="space-y-2">
              {col.links.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-ink-muted transition-colors hover:text-berry-500 dark:hover:text-cream"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}

        <div>
          <h3 className="mb-3 font-display text-sm font-semibold uppercase tracking-wide text-berry-500 dark:text-cream">
            Контакты
          </h3>
          <ul className="space-y-2.5 text-sm text-ink-muted">
            <li className="flex items-start gap-2">
              <Phone className="mt-0.5 h-4 w-4 shrink-0" /> {SITE.phone}
            </li>
            <li className="flex items-start gap-2">
              <MapPin className="mt-0.5 h-4 w-4 shrink-0" /> {SITE.address}
            </li>
            <li>{SITE.workHours}</li>
          </ul>
        </div>
      </div>

      <div className="border-t border-pink-100/70 py-5 dark:border-berry-300/20">
        <div className="container-sweetime flex flex-col items-center justify-between gap-2 text-xs text-ink-muted sm:flex-row">
          <p>© {new Date().getFullYear()} {SITE.fullName}. Все права защищены.</p>
          <div className="flex gap-4">
            <Link href="/privacy" className="hover:text-berry-500 dark:hover:text-cream">
              Политика конфиденциальности
            </Link>
            <Link href="/terms" className="hover:text-berry-500 dark:hover:text-cream">
              Условия использования
            </Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
