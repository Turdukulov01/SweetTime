import type { AdminUser } from '@/types';
import { formatDate } from '@/lib/utils';

export function UsersTable({ users }: { users: AdminUser[] }) {
  return (
    <div className="overflow-x-auto rounded-3xl border border-pink-100/70 dark:border-berry-300/20">
      <table className="w-full min-w-[560px] text-left text-sm">
        <thead className="bg-pink-50 text-xs uppercase tracking-wide text-ink-muted dark:bg-berry-600/40">
          <tr>
            <th className="px-4 py-3">Клиент</th>
            <th className="px-4 py-3">Телефон</th>
            <th className="px-4 py-3">Заказов</th>
            <th className="px-4 py-3">Бонусы</th>
            <th className="px-4 py-3">В базе с</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-pink-100/70 dark:divide-berry-300/10">
          {users.map((user) => (
            <tr key={user.id}>
              <td className="px-4 py-3 font-medium text-ink dark:text-cream">{user.name}</td>
              <td className="px-4 py-3 text-ink-muted">{user.phone}</td>
              <td className="px-4 py-3">{user.orders}</td>
              <td className="px-4 py-3">{user.bonusBalance} ★</td>
              <td className="px-4 py-3 text-ink-muted">{formatDate(user.joined)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
