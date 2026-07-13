import { Login, LoginForm } from 'react-admin';
import { Box, Typography } from '@mui/material';

export function LoginPage() {
  return (
    <Login>
      <Box sx={{ textAlign: 'center', mb: 3 }}>
        <Typography variant="h4" fontWeight={900}>
          SweetTime Admin
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Demo: owner@sweettime.kg / sweettime123
        </Typography>
      </Box>
      <LoginForm />
    </Login>
  );
}
