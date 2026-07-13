import simpleRestProvider from 'ra-data-simple-rest';
import { fetchUtils } from 'react-admin';

const apiUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:8000';

const httpClient = (url: string, options: fetchUtils.Options = {}) => {
  const token = localStorage.getItem('sweettime_token');
  const headers = new Headers(options.headers ?? { Accept: 'application/json' });
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  return fetchUtils.fetchJson(url, { ...options, headers });
};

export const dataProvider = simpleRestProvider(`${apiUrl}/admin`, httpClient);
