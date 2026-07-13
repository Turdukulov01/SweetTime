import type { MetadataRoute } from 'next';
import { PRODUCTS, CATEGORIES } from '@/lib/mock-data';
import { SITE } from '@/lib/constants';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = SITE.url;

  const staticRoutes: MetadataRoute.Sitemap = [
    { url: base, lastModified: new Date(), changeFrequency: 'daily', priority: 1 },
    { url: `${base}/catalog`, lastModified: new Date(), changeFrequency: 'daily', priority: 0.9 },
    { url: `${base}/auth/login`, lastModified: new Date(), changeFrequency: 'monthly', priority: 0.4 },
    { url: `${base}/auth/register`, lastModified: new Date(), changeFrequency: 'monthly', priority: 0.4 },
    { url: `${base}/promotions`, lastModified: new Date(), changeFrequency: 'weekly', priority: 0.7 },
  ];

  const categoryRoutes: MetadataRoute.Sitemap = CATEGORIES.map((cat) => ({
    url: `${base}/catalog?category=${cat.slug}`,
    lastModified: new Date(),
    changeFrequency: 'weekly' as const,
    priority: 0.8,
  }));

  const productRoutes: MetadataRoute.Sitemap = PRODUCTS.map((p) => ({
    url: `${base}/product/${p.slug}`,
    lastModified: new Date(),
    changeFrequency: 'weekly' as const,
    priority: 0.7,
  }));

  return [...staticRoutes, ...categoryRoutes, ...productRoutes];
}
