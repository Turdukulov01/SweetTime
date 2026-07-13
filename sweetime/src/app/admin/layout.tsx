import { AdminSidebar } from '@/components/admin/Sidebar';

export const metadata = { title: 'Админ-панель', robots: { index: false, follow: false } };

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="container-sweetime py-8">
      <h1 className="mb-6 font-display text-2xl font-semibold text-berry-500 dark:text-cream">
        Sweetime Admin
      </h1>
      <div className="flex flex-col gap-8 lg:flex-row">
        <AdminSidebar />
        <div className="min-w-0 flex-1">{children}</div>
      </div>
    </div>
  );
}
