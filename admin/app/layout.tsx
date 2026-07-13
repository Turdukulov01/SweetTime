import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin", "cyrillic"],
  variable: "--font-sans",
  display: "swap"
});

export const metadata: Metadata = {
  title: {
    default: "SweetTime Admin",
    template: "%s | SweetTime Admin"
  },
  description:
    "Единая админ-панель SweetTime: заказы, меню, филиалы и настройки приложения для кофеен."
};

// Применяем сохранённую тему ДО первого рендера, чтобы не мигало белым
const themeInitScript = `try{if(localStorage.getItem("admin-theme")==="dark")document.documentElement.classList.add("dark")}catch(e){}`;

export default function RootLayout({
  children
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ru" className={inter.variable} suppressHydrationWarning>
      <body className="antialiased">
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
        {children}
      </body>
    </html>
  );
}
