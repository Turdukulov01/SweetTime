import type { AuthProvider } from 'react-admin';

const apiUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:8000';

export const authProvider: AuthProvider = {
  async login({ username, password }) {
    const response = await fetch(`${apiUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: username, password }),
    });
    if (!response.ok) {
      throw new Error('Неверный логин или пароль');
    }
    const data = await response.json();
    localStorage.setItem('sweettime_token', data.access_token);
    localStorage.setItem('sweettime_refresh', data.refresh_token);
  },
  async logout() {
    localStorage.removeItem('sweettime_token');
    localStorage.removeItem('sweettime_refresh');
  },
  async checkError(error) {
    if (error.status === 401 || error.status === 403) {
      localStorage.removeItem('sweettime_token');
      throw new Error('Unauthorized');
    }
  },
  async checkAuth() {
    if (!localStorage.getItem('sweettime_token')) {
      throw new Error('Unauthorized');
    }
  },
  async getPermissions() {
    return Promise.resolve('staff');
  },
  async getIdentity() {
    return {
      id: 'admin',
      fullName: 'SweetTime Admin',
    };
  },
};
