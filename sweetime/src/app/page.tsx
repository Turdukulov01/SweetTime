import { HeroBanner } from '@/components/home/HeroBanner';
import { Promotions } from '@/components/home/Promotions';
import { Categories } from '@/components/home/Categories';
import { PopularDrinks } from '@/components/home/PopularDrinks';
import { NewArrivals } from '@/components/home/NewArrivals';
import { BestSellers } from '@/components/home/BestSellers';
import { Reviews } from '@/components/home/Reviews';

export default function HomePage() {
  return (
    <>
      <HeroBanner />
      <Promotions />
      <Categories />
      <PopularDrinks />
      <NewArrivals />
      <BestSellers />
      <Reviews />
    </>
  );
}
