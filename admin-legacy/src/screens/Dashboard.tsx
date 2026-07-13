import { useEffect, useState } from 'react';
import { Card, CardContent, Grid2, Typography } from '@mui/material';
import { Title } from 'react-admin';

const apiUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:8000';

type DashboardStats = {
  orders: number;
  products: number;
  branches: number;
  users: number;
};

export function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('sweettime_token');
    fetch(`${apiUrl}/admin/dashboard`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
      .then((response) => response.json())
      .then(setStats)
      .catch(() => setStats(null));
  }, []);

  const cards = [
    ['Заказы', stats?.orders ?? 0],
    ['Товары', stats?.products ?? 0],
    ['Филиалы', stats?.branches ?? 0],
    ['Пользователи', stats?.users ?? 0],
  ];

  return (
    <>
      <Title title="SweetTime Dashboard" />
      <Grid2 container spacing={2} sx={{ mt: 1 }}>
        {cards.map(([label, value]) => (
          <Grid2 key={label} size={{ xs: 12, sm: 6, md: 3 }}>
            <Card>
              <CardContent>
                <Typography color="text.secondary">{label}</Typography>
                <Typography variant="h4" fontWeight={900}>
                  {value}
                </Typography>
              </CardContent>
            </Card>
          </Grid2>
        ))}
      </Grid2>
    </>
  );
}
