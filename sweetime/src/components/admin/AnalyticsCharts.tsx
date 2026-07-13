'use client';

import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { AnalyticsPoint } from '@/types';
import { Card } from '@/components/ui/Card';

export function AnalyticsCharts({ data }: { data: AnalyticsPoint[] }) {
  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <Card>
        <h3 className="mb-4 font-display font-semibold text-berry-500 dark:text-cream">
          Выручка по дням
        </h3>
        <ResponsiveContainer width="100%" height={260}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#F3E4CE" />
            <XAxis dataKey="label" stroke="#8A7A7E" fontSize={12} />
            <YAxis stroke="#8A7A7E" fontSize={12} />
            <Tooltip
              contentStyle={{ borderRadius: 16, border: '1px solid #F9C7D0', fontSize: 13 }}
            />
            <Bar dataKey="revenue" fill="#F6B8C4" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </Card>

      <Card>
        <h3 className="mb-4 font-display font-semibold text-berry-500 dark:text-cream">
          Количество заказов
        </h3>
        <ResponsiveContainer width="100%" height={260}>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#F3E4CE" />
            <XAxis dataKey="label" stroke="#8A7A7E" fontSize={12} />
            <YAxis stroke="#8A7A7E" fontSize={12} />
            <Tooltip
              contentStyle={{ borderRadius: 16, border: '1px solid #BFE8DC', fontSize: 13 }}
            />
            <Line type="monotone" dataKey="orders" stroke="#5FB79E" strokeWidth={3} dot={{ r: 4 }} />
          </LineChart>
        </ResponsiveContainer>
      </Card>
    </div>
  );
}
