import 'package:flutter/material.dart';

import 'app_models.dart';

/// Демо-данные повторяют утверждённый прототип (sweettimetwo) — см. docs/design/DESIGN_SYSTEM.md.
class DemoData {
  static const branches = [
    Branch(
      id: 'b1',
      name: LocalizedText(
        ru: 'SweetTime на Чуй',
        ky: 'Чүйдөгү SweetTime',
        en: 'SweetTime on Chuy',
      ),
      address: LocalizedText(
        ru: 'ул. Чуй 123, Бишкек',
        ky: 'Чүй көчөсү 123, Бишкек',
        en: '123 Chuy Street, Bishkek',
      ),
      hours: '09:00–22:00',
      phone: '+996 700 123 456',
      isOpen: true,
      twoGisUrl: 'https://2gis.kg/bishkek',
      googleMapsUrl: 'https://maps.google.com',
    ),
    Branch(
      id: 'b2',
      name: LocalizedText(
        ru: 'SweetTime на Манаса',
        ky: 'Манастагы SweetTime',
        en: 'SweetTime on Manas',
      ),
      address: LocalizedText(
        ru: 'пр. Манаса 56, Бишкек',
        ky: 'Манас проспекти 56, Бишкек',
        en: '56 Manas Avenue, Bishkek',
      ),
      hours: '10:00–22:00',
      phone: '+996 700 123 457',
      isOpen: true,
      twoGisUrl: 'https://2gis.kg/bishkek',
      googleMapsUrl: 'https://maps.google.com',
    ),
    Branch(
      id: 'b3',
      name: LocalizedText(
        ru: 'SweetTime в ТРЦ Bishkek Park',
        ky: 'Bishkek Park соода борборундагы SweetTime',
        en: 'SweetTime at Bishkek Park',
      ),
      address: LocalizedText(
        ru: 'ул. Ибраимова 115, Бишкек',
        ky: 'Ибраимов көчөсү 115, Бишкек',
        en: '115 Ibraimov Street, Bishkek',
      ),
      hours: '10:00–21:00',
      phone: '+996 700 123 458',
      isOpen: true,
      twoGisUrl: 'https://2gis.kg/bishkek',
      googleMapsUrl: 'https://maps.google.com',
    ),
  ];

  static const milkTeaCategory = MenuCategory(
    id: 'milk-tea',
    name: LocalizedText(ru: 'Молочный чай', ky: 'Сүттүү чай', en: 'Milk tea'),
  );
  static const fruitTeaCategory = MenuCategory(
    id: 'fruit-tea',
    name: LocalizedText(
      ru: 'Фруктовый чай',
      ky: 'Мөмө-жемиш чайы',
      en: 'Fruit tea',
    ),
  );
  static const coffeeCategory = MenuCategory(
    id: 'coffee',
    name: LocalizedText(ru: 'Кофе', ky: 'Кофе', en: 'Coffee'),
  );
  static const dessertsCategory = MenuCategory(
    id: 'desserts',
    name: LocalizedText(ru: 'Десерты', ky: 'Десерттер', en: 'Desserts'),
  );

  static const categories = [
    milkTeaCategory,
    fruitTeaCategory,
    coffeeCategory,
    dessertsCategory,
  ];

  static const sugarLevels = [0, 30, 50, 70, 100];
  static const iceLevels = IceLevel.values;

  static const _sizes = [
    ModifierOption(
      id: 's',
      name: LocalizedText(ru: 'S', ky: 'S', en: 'S'),
      priceDelta: -30,
    ),
    ModifierOption(
      id: 'm',
      name: LocalizedText(ru: 'M', ky: 'M', en: 'M'),
      priceDelta: 0,
    ),
    ModifierOption(
      id: 'l',
      name: LocalizedText(ru: 'L', ky: 'L', en: 'L'),
      priceDelta: 50,
    ),
  ];

  static const _toppings = [
    ModifierOption(
      id: 'tapioca',
      name: LocalizedText(
        ru: 'Шарики тапиоки',
        ky: 'Тапиока шариктери',
        en: 'Tapioca pearls',
      ),
      priceDelta: 50,
    ),
    ModifierOption(
      id: 'cheese-foam',
      name: LocalizedText(
        ru: 'Сырная пенка',
        ky: 'Сыр көбүгү',
        en: 'Cheese foam',
      ),
      priceDelta: 60,
    ),
    ModifierOption(
      id: 'aloe-jelly',
      name: LocalizedText(ru: 'Желе алоэ', ky: 'Алоэ желеси', en: 'Aloe jelly'),
      priceDelta: 40,
    ),
    ModifierOption(
      id: 'brown-sugar-pearls',
      name: LocalizedText(
        ru: 'Шарики с коричневым сахаром',
        ky: 'Күрөң канттуу шариктер',
        en: 'Brown sugar pearls',
      ),
      priceDelta: 50,
    ),
    ModifierOption(
      id: 'pudding',
      name: LocalizedText(ru: 'Пудинг', ky: 'Пудинг', en: 'Pudding'),
      priceDelta: 45,
    ),
    ModifierOption(
      id: 'coffee-jelly',
      name: LocalizedText(
        ru: 'Кофейное желе',
        ky: 'Кофе желеси',
        en: 'Coffee jelly',
      ),
      priceDelta: 45,
    ),
  ];

  static const _allBranches = ['b1', 'b2', 'b3'];

  static const products = [
    Product(
      id: 'p1',
      category: milkTeaCategory,
      name: LocalizedText(
        ru: 'Розовая луна с молочным чаем',
        ky: 'Кызгылт ай сүттүү чайы',
        en: 'Pink Moon milk tea',
      ),
      description: LocalizedText(
        ru: 'Сливочный клубничный улун с шариками в коричневом сахаре и воздушной пенкой.',
        ky: 'Каймактуу кулпунай улууну, күрөң канттуу шариктер жана үлпүлдөк көбүк.',
        en: 'Creamy strawberry oolong with brown sugar pearls and airy foam.',
      ),
      basePrice: 350,
      accentColor: Color(0xFFFF9EC6),
      rating: 4.9,
      reviewsCount: 328,
      isBestSeller: true,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
      assetImage: 'assets/images/brown-sugar-bubble-tea.png',
    ),
    Product(
      id: 'p2',
      category: milkTeaCategory,
      name: LocalizedText(
        ru: 'Матча мятное облако',
        ky: 'Жалбыз булуттуу матча',
        en: 'Matcha Mint Cloud',
      ),
      description: LocalizedText(
        ru: 'Церемониальная матча, мятное молоко, ванильная пенка и мягкая тапиока.',
        ky: 'Салтанаттуу матча, жалбыз сүтү, ваниль көбүгү жана жумшак тапиока.',
        en: 'Ceremonial matcha, mint milk, vanilla foam and soft tapioca.',
      ),
      basePrice: 390,
      accentColor: Color(0xFF8FE5C7),
      rating: 4.8,
      reviewsCount: 214,
      isNew: true,
      sizes: _sizes,
      toppings: _toppings,
      // недоступен в ТРЦ Bishkek Park — демо сообщения о недоступности
      availableBranchIds: ['b1', 'b2'],
      assetImage: 'assets/images/matcha-bubble-tea.png',
    ),
    Product(
      id: 'p3',
      category: coffeeCategory,
      name: LocalizedText(
        ru: 'Латте с коричневым сахаром',
        ky: 'Күрөң канттуу латте',
        en: 'Brown Sugar Latte',
      ),
      description: LocalizedText(
        ru: 'Нежный латте на эспрессо с карамельным сиропом и теплыми шариками.',
        ky: 'Эспрессо кошулган жумшак латте, карамель сиробу жана жылуу шариктер.',
        en: 'Smooth espresso latte with caramel syrup and warm pearls.',
      ),
      basePrice: 370,
      accentColor: Color(0xFFB98560),
      rating: 4.7,
      reviewsCount: 188,
      isBestSeller: true,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
      assetImage: 'assets/images/brown-sugar-bubble-tea.png',
    ),
    Product(
      id: 'p4',
      category: fruitTeaCategory,
      name: LocalizedText(
        ru: 'Персиковый жасмин',
        ky: 'Шабдалы жасмини',
        en: 'Peach Jasmine',
      ),
      description: LocalizedText(
        ru: 'Зеленый чай с жасмином, персиковое пюре, цитрусовая свежесть и желе алоэ.',
        ky: 'Жасмин көк чайы, шабдалы пюреси, цитрус сергектиги жана алоэ желеси.',
        en: 'Jasmine green tea, peach puree, fresh citrus and aloe jelly.',
      ),
      basePrice: 330,
      accentColor: Color(0xFFFFD39E),
      rating: 4.8,
      reviewsCount: 167,
      isNew: true,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
    ),
    Product(
      id: 'p5',
      category: coffeeCategory,
      name: LocalizedText(
        ru: 'Какао фрост с шариками',
        ky: 'Шариктүү муздак какао',
        en: 'Pearl Cocoa Frost',
      ),
      description: LocalizedText(
        ru: 'Холодное какао, легкий эспрессо, сливочная шапка и кофейное желе.',
        ky: 'Муздак какао, жеңил эспрессо, каймак көбүгү жана кофе желеси.',
        en: 'Iced cocoa, light espresso, cream topping and coffee jelly.',
      ),
      basePrice: 360,
      accentColor: Color(0xFF7B4B35),
      rating: 4.6,
      reviewsCount: 142,
      sizes: _sizes,
      toppings: _toppings,
      // недоступен на Манаса — демо сообщения о недоступности
      availableBranchIds: ['b1', 'b3'],
    ),
    Product(
      id: 'p6',
      category: fruitTeaCategory,
      name: LocalizedText(
        ru: 'Манговый сливочный чай',
        ky: 'Каймактуу манго чайы',
        en: 'Creamy Mango Tea',
      ),
      description: LocalizedText(
        ru: 'Сочное манго, черный чай, кокосовые сливки и взрывные шарики.',
        ky: 'Ширелүү манго, кара чай, кокос каймагы жана жарылуучу шариктер.',
        en: 'Juicy mango, black tea, coconut cream and popping pearls.',
      ),
      basePrice: 340,
      accentColor: Color(0xFFFFC857),
      rating: 4.7,
      reviewsCount: 119,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
    ),
    Product(
      id: 'p7',
      category: coffeeCategory,
      name: LocalizedText(
        ru: 'Колд брю ванильная роза',
        ky: 'Ваниль розалуу колд брю',
        en: 'Vanilla Rose Cold Brew',
      ),
      description: LocalizedText(
        ru: 'Мягкий колд брю с розово-ванильными сливками и нежной пенкой.',
        ky: 'Роза-ваниль каймагы жана назик көбүгү бар жумшак колд брю.',
        en: 'Smooth cold brew with rose-vanilla cream and delicate foam.',
      ),
      basePrice: 330,
      accentColor: Color(0xFFEFB8C8),
      rating: 4.9,
      reviewsCount: 96,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
    ),
    Product(
      id: 'p8',
      category: dessertsCategory,
      name: LocalizedText(
        ru: 'Клубничный моти-кап',
        ky: 'Кулпунай моти-кабы',
        en: 'Strawberry Mochi Cup',
      ),
      description: LocalizedText(
        ru: 'Слои моти-крема, клубничного компоте, бисквитной крошки и чайного желе.',
        ky: 'Моти каймагы, кулпунай компотеси, бисквит күкүмү жана чай желесинин катмарлары.',
        en: 'Layers of mochi cream, strawberry compote, cake crumbs and tea jelly.',
      ),
      basePrice: 290,
      accentColor: Color(0xFFFFB3C7),
      rating: 4.8,
      reviewsCount: 203,
      isBestSeller: true,
      sizes: _sizes,
      toppings: _toppings,
      availableBranchIds: _allBranches,
    ),
  ];

  static const promotions = [
    Promotion(
      id: 'promo-duo',
      title: LocalizedText(
        ru: 'Утренний дуэт',
        ky: 'Эртең мененки дуэт',
        en: 'Morning Duo',
      ),
      description: LocalizedText(
        ru: 'Любой кофе и моти-кап за 520 сом',
        ky: 'Каалаган кофе жана моти-кап 520 сомго',
        en: 'Any coffee and a mochi cup for KGS 520',
      ),
      code: 'DUO',
    ),
    Promotion(
      id: 'promo-pearls',
      title: LocalizedText(
        ru: 'Час шариков',
        ky: 'Шариктер сааты',
        en: 'Pearl Hour',
      ),
      description: LocalizedText(
        ru: 'Бесплатная тапиока после 16:00',
        ky: '16:00дөн кийин тапиока акысыз',
        en: 'Free tapioca after 16:00',
      ),
      code: 'PEARLS',
    ),
    Promotion(
      id: 'promo-mint',
      title: LocalizedText(
        ru: 'Мятный понедельник',
        ky: 'Жалбыз дүйшөмбү',
        en: 'Mint Monday',
      ),
      description: LocalizedText(
        ru: 'Вдвое больше баллов за зеленые напитки',
        ky: 'Жашыл суусундуктар үчүн эки эсе көп упай',
        en: 'Double points on green drinks',
      ),
      code: 'MINT',
    ),
  ];

  static const newsStories = [
    NewsStory(
      id: 'news-week-flavor',
      title: LocalizedText(
        ru: 'Новый вкус недели',
        ky: 'Аптанын жаңы даамы',
        en: 'Flavor of the week',
      ),
      body: LocalizedText(
        ru: 'Попробуйте клубничный улун с воздушной сырной пенкой — только до воскресенья.',
        ky: 'Кулпунай улунун жумшак сыр көбүгү менен татып көрүңүз — жекшембиге чейин гана.',
        en: 'Try strawberry oolong with airy cheese foam — available through Sunday only.',
      ),
      badge: LocalizedText(ru: 'Новинка', ky: 'Жаңы', en: 'New'),
      accentHex: 0xFFFF8FBD,
      visual: NewsStoryVisual.sparkle,
      publishedAt: '2026-07-13T00:00:00Z',
      sortOrder: 10,
    ),
    NewsStory(
      id: 'news-manas',
      title: LocalizedText(
        ru: 'Мы открылись на Манаса',
        ky: 'Манас көчөсүндө ачылдык',
        en: 'Now open on Manas',
      ),
      body: LocalizedText(
        ru: 'Новый филиал уже принимает заказы. Заходите ежедневно с 10:00 до 22:00.',
        ky: 'Жаңы филиал заказдарды кабыл алууда. Күн сайын 10:00дөн 22:00гө чейин келиңиз.',
        en: 'Our new branch is taking orders daily from 10:00 to 22:00.',
      ),
      badge: LocalizedText(ru: 'Филиал', ky: 'Филиал', en: 'Branch'),
      accentHex: 0xFF8FDCC4,
      visual: NewsStoryVisual.storefront,
      publishedAt: '2026-07-10T00:00:00Z',
      sortOrder: 20,
    ),
    NewsStory(
      id: 'news-table-qr',
      title: LocalizedText(
        ru: 'Заказ со столика',
        ky: 'Столдон заказ бериңиз',
        en: 'Order from your table',
      ),
      body: LocalizedText(
        ru: 'Отсканируйте QR в кафе, соберите напиток и не стойте в очереди.',
        ky: 'Кафедеги QR кодду сканерлеп, суусундукту тандап, кезек күтпөңүз.',
        en: 'Scan the in-cafe QR, customize your drink and skip the queue.',
      ),
      badge: LocalizedText(ru: 'Совет', ky: 'Кеңеш', en: 'Tip'),
      accentHex: 0xFFFFC96B,
      visual: NewsStoryVisual.qr,
      publishedAt: '2026-07-08T00:00:00Z',
      sortOrder: 30,
    ),
    NewsStory(
      id: 'news-double-points',
      title: LocalizedText(
        ru: 'Двойные баллы',
        ky: 'Эки эсе упай',
        en: 'Double points',
      ),
      body: LocalizedText(
        ru: 'Каждый понедельник начисляем вдвое больше баллов за напитки с матчей.',
        ky: 'Ар дүйшөмбүдө матча суусундуктары үчүн эки эсе көп упай беребиз.',
        en: 'Earn double points on matcha drinks every Monday.',
      ),
      badge: LocalizedText(ru: 'Лояльность', ky: 'Лоялдуулук', en: 'Loyalty'),
      accentHex: 0xFFA9D88E,
      visual: NewsStoryVisual.loyalty,
      publishedAt: '2026-07-06T00:00:00Z',
      sortOrder: 40,
    ),
  ];

  static const pointEvents = [
    PointEvent(
      title: LocalizedText(
        ru: 'Начисление за SW-1048',
        ky: 'SW-1048 үчүн упай кошулду',
        en: 'Points earned for SW-1048',
      ),
      amount: 32,
      date: LocalizedText(ru: '02.07.2026', ky: '02.07.2026', en: '2026-07-02'),
    ),
    PointEvent(
      title: LocalizedText(
        ru: 'Начисление за SW-1031',
        ky: 'SW-1031 үчүн упай кошулду',
        en: 'Points earned for SW-1031',
      ),
      amount: 35,
      date: LocalizedText(ru: '25.06.2026', ky: '25.06.2026', en: '2026-06-25'),
    ),
    PointEvent(
      title: LocalizedText(
        ru: 'Бонус за приглашение друга',
        ky: 'Дос чакыруу бонусу',
        en: 'Friend invitation bonus',
      ),
      amount: 100,
      date: LocalizedText(ru: '20.06.2026', ky: '20.06.2026', en: '2026-06-20'),
    ),
  ];

  static const favoriteIds = ['p1', 'p4', 'p7'];

  static const demoUserFirstName = 'Айгерим';
  static const demoUserLastName = '';
  static const demoUserPhone = '+996 555 123 456';
  // Личный 6-значный код: карта лояльности на кассе + реферальный код (см. REFERRAL_LOGIC.md)
  static const demoUserCode = '512347';
  static const demoPoints = 1240;
  static const expiringPointsAmount = 120;
  static const expiringPointsDate = '01.02.2027';
  static const demoOtpCode = '1111';
}
