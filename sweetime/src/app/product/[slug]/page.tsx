import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Flame, Star, Zap } from 'lucide-react';
import { PRODUCTS, REVIEWS, getProductBySlug, getRelatedProducts } from '@/lib/mock-data';
import { Gallery } from '@/components/product/Gallery';
import { ProductCustomizer } from '@/components/product/Customizer';
import { ReviewsList } from '@/components/product/ReviewsList';
import { Recommendations } from '@/components/product/Recommendations';
import { Badge, TAG_LABELS } from '@/components/ui/Badge';

export function generateStaticParams() {
  return PRODUCTS.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const product = getProductBySlug(slug);
  if (!product) return {};
  return {
    title: product.name,
    description: product.description,
    openGraph: { images: [{ url: product.images[0] }] },
  };
}

export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = getProductBySlug(slug);
  if (!product) notFound();

  const reviews = REVIEWS.filter((r) => r.productId === product.id);
  const related = getRelatedProducts(product);

  return (
    <div className="container-sweetime space-y-16 py-10">
      <div className="grid gap-10 lg:grid-cols-2">
        <Gallery images={product.images} name={product.name} />

        <div>
          {product.tags.length > 0 && (
            <div className="mb-3 flex gap-1.5">
              {product.tags.map((tag) => (
                <Badge key={tag} tone={TAG_LABELS[tag].tone}>
                  {TAG_LABELS[tag].label}
                </Badge>
              ))}
            </div>
          )}
          <h1 className="font-display text-3xl font-semibold text-berry-500 sm:text-4xl dark:text-cream">
            {product.name}
          </h1>
          <div className="mt-2 flex items-center gap-4 text-sm text-ink-muted">
            <span className="flex items-center gap-1">
              <Star className="h-4 w-4 fill-caramel-500 text-caramel-500" />
              <span className="font-semibold text-ink dark:text-cream">{product.rating}</span> (
              {product.reviewsCount} отзывов)
            </span>
            <span className="flex items-center gap-1">
              <Flame className="h-4 w-4" /> {product.calories} ккал
            </span>
            <span className="flex items-center gap-1">
              <Zap className="h-4 w-4" /> кофеин: {product.caffeine}
            </span>
          </div>
          <p className="mt-4 leading-relaxed text-ink-muted">{product.description}</p>

          <div className="mt-8">
            <ProductCustomizer product={product} />
          </div>
        </div>
      </div>

      <section>
        <h2 className="section-heading mb-6">Отзывы</h2>
        <ReviewsList reviews={reviews} />
      </section>

      <Recommendations products={related} />
    </div>
  );
}
