import { fetchAdminUsers } from '@/lib/api';
import { UsersTable } from '@/components/admin/UsersTable';

export const metadata = { title: 'Пользователи — Admin' };

export default async function AdminUsersPage() {
  const users = await fetchAdminUsers();
  return (
    <div>
      <h2 className="mb-6 font-display text-xl font-semibold text-berry-500 dark:text-cream">
        Пользователи
      </h2>
      <UsersTable users={users} />
    </div>
  );
}
