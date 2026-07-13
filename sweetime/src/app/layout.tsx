import type { Metadata } from 'next';
import { Fraunces, Plus_Jakarta_Sans, IBM_Plex_Mono } from 'next/font/google';
import './globals.css';
import { CartProvider } from '@/context/CartContext';
import { AuthProvider } from '@/context/AuthContext';
import { ThemeProvider } from '@/context/ThemeContext';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { SITE } from '@/lib/constants';

const fraunces = Fraunces({
  // Fraunces не поддерживает кириллицу; русские заголовки уходят в fallback-serif
  subsets: ['latin', 'latin-ext'],
  variable: '--font-fraunces',
  weight: ['500', '600', '700', '900'],
  display: 'swap',
});

const jakarta = Plus_Jakarta_Sans({
  // Plus Jakarta Sans тоже без кириллицы — русский текст рендерится системным fallback
  subsets: ['latin', 'latin-ext'],
  variable: '--font-jakarta',
  weight: ['400', '500', '600', '700'],
  display: 'swap',
});

const mono = IBM_Plex_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  weight: ['400', '500'],
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: {
    default: `${SITE.fullName} — бабл-ти и кофе с доставкой`,
    template: `%s — ${SITE.name}`,
  },
  description: SITE.description,
  keywords: ['бабл ти', 'bubble tea', 'кофе', 'доставка напитков', 'Sweetime', 'Бишкек'],
  openGraph: {
    type: 'website',
    locale: 'ru_RU',
    siteName: SITE.fullName,
    title: `${SITE.fullName} — бабл-ти и кофе с доставкой`,
    description: SITE.description,
  },
  twitter: {
    card: 'summary_large_image',
    title: SITE.fullName,
    description: SITE.description,
  },
  icons: { icon: '/favicon.ico' },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" className={`${fraunces.variable} ${jakarta.variable} ${mono.variable}`}>
      <body>
        <ThemeProvider>
          <AuthProvider>
            <CartProvider>
              <Header />
              <main className="min-h-[60vh]">{children}</main>
              <Footer />
            </CartProvider>
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
