import type { IceLevel, Size, SugarLevel } from '@/types';

export const SITE = {
  name: 'Sweetime',
  fullName: 'Sweetime Bubble Tea & Coffee',
  description:
    'Sweetime — авторский бабл-ти и кофе на пастельном пироге радости. Заказывайте онлайн с доставкой или самовывозом.',
  url: 'https://sweetime.example.com',
  phone: '+7 (700) 123-45-67',
  address: 'г. Бишкек, ул. Чуй 123',
  workHours: '09:00 – 22:00, без выходных',
};

export const NAV_LINKS = [
  { href: '/catalog', label: 'Каталог' },
  { href: '/catalog?tag=bestseller', label: 'Хиты' },
  { href: '/catalog?tag=new', label: 'Новинки' },
  { href: '/promotions', label: 'Акции' },
];

export const SIZES: Array<{ value: Size; label: string; volumeMl: number; priceDelta: number }> = [
  { value: 'S', label: 'S', volumeMl: 350, priceDelta: 0 },
  { value: 'M', label: 'M', volumeMl: 500, priceDelta: 60 },
  { value: 'L', label: 'L', volumeMl: 700, priceDelta: 120 },
];

export const ICE_LEVELS: IceLevel[] = ['Без льда', 'Мало льда', 'Стандарт', 'Много льда'];

export const SUGAR_LEVELS: SugarLevel[] = ['0%', '30%', '50%', '70%', '100%', '120%'];

export const TOPPINGS = [
  { id: 'boba-classic', name: 'Классическая тапиока', price: 60 },
  { id: 'boba-brown', name: 'Тапиока в карамели', price: 70 },
  { id: 'popping-strawberry', name: 'Попинг-боба клубника', price: 80 },
  { id: 'popping-mango', name: 'Попинг-боба манго', price: 80 },
  { id: 'cheese-foam', name: 'Сырная пенка', price: 90 },
  { id: 'jelly', name: 'Кофейное желе', price: 60 },
  { id: 'pudding', name: 'Пудинг', price: 70 },
  { id: 'aloe', name: 'Кубики алоэ', price: 65 },
];

export const DELIVERY_FEE = 250;
export const FREE_DELIVERY_THRESHOLD = 1500;
export const BONUS_EARN_RATE = 0.05; // 5% of order back as bonuses
export const BONUS_MAX_REDEEM_SHARE = 0.3; // can cover up to 30% of order with bonuses
