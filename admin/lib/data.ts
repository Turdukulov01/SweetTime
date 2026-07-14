// Мок-данные двух демо-компаний с ПОЛНОСТЬЮ раздельными данными.
// Правило изоляции тенантов: массивы ниже НЕ экспортируются.
// Компоненты получают данные только через getCompanyData(companyId),
// пользователей — только через authenticate()/getAdminUser().

import type {
  AdminUser,
  Branch,
  Company,
  CompanyData,
  NewsStory,
  Order,
  Product,
  Promotion,
  RecurringOrder
} from "@/lib/types";

// ---------------------------------------------------------------------------
// Вспомогательные генераторы времени: демо-заказы всегда «свежие»
// ---------------------------------------------------------------------------

function minutesAgo(minutes: number): string {
  return new Date(Date.now() - minutes * 60_000).toISOString();
}

function yesterdayAt(hours: number, minutes: number): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  d.setHours(hours, minutes, 0, 0);
  return d.toISOString();
}

function daysFromNow(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(23, 59, 0, 0);
  return d.toISOString();
}

function daysAgo(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(9, 0, 0, 0);
  return d.toISOString();
}

// ---------------------------------------------------------------------------
// Компании
// ---------------------------------------------------------------------------

const companies: Company[] = [
  {
    id: "sweettime",
    name: "SweetTime",
    appName: "SweetTime",
    accentColor: "#FF5C9A",
    currency: "сом",
    loyalty: { earnRate: 0.05, maxSpendShare: 0.3, expiryMonths: 12 },
    referral: { invitedBonus: 50, inviterBonus: 100 }
  },
  {
    id: "coffeego",
    name: "CoffeeGo",
    appName: "CoffeeGo",
    accentColor: "#34C99A",
    currency: "сом",
    loyalty: { earnRate: 0.03, maxSpendShare: 0.2, expiryMonths: 6 },
    referral: { invitedBonus: 30, inviterBonus: 70 }
  }
];

// ---------------------------------------------------------------------------
// Сотрудники (пароль у всех демо-аккаунтов: demo)
// ---------------------------------------------------------------------------

type DemoUser = AdminUser & { password: string };

const adminUsers: DemoUser[] = [
  {
    id: "u1",
    email: "owner@sweettime.kg",
    name: "Айгерим Осмонова",
    role: "owner",
    companyId: "sweettime",
    password: "demo"
  },
  {
    id: "u2",
    email: "manager@sweettime.kg",
    name: "Данияр Жумалиев",
    role: "manager",
    companyId: "sweettime",
    password: "demo"
  },
  {
    id: "u3",
    email: "barista@sweettime.kg",
    name: "Салтанат Бекова",
    role: "barista",
    companyId: "sweettime",
    branchId: "b1",
    password: "demo"
  },
  {
    id: "u4",
    email: "owner@coffeego.kg",
    name: "Тимур Абдыраимов",
    role: "owner",
    companyId: "coffeego",
    password: "demo"
  }
];

// ---------------------------------------------------------------------------
// SweetTime: 3 филиала и 8 напитков — точно по docs/design/DESIGN_SYSTEM.md
// ---------------------------------------------------------------------------

const sweettimeBranches: Branch[] = [
  {
    id: "b1",
    companyId: "sweettime",
    name: "SweetTime на Чуй",
    address: "ул. Чуй 123, Бишкек",
    hours: "09:00–22:00",
    phone: "+996 312 90 01 01",
    isOpen: true
  },
  {
    id: "b2",
    companyId: "sweettime",
    name: "SweetTime на Манаса",
    address: "пр. Манаса 56, Бишкек",
    hours: "10:00–22:00",
    phone: "+996 312 90 01 02",
    isOpen: true
  },
  {
    id: "b3",
    companyId: "sweettime",
    name: "SweetTime в ТРЦ Bishkek Park",
    address: "ул. Ибраимова 115, Бишкек",
    hours: "10:00–21:00",
    phone: "+996 312 90 01 03",
    isOpen: true
  }
];

const drinkSizes = [
  { id: "s", label: "S", priceDelta: 0 },
  { id: "m", label: "M", priceDelta: 40 },
  { id: "l", label: "L", priceDelta: 70 }
];

const sweettimeProducts: Product[] = [
  {
    id: "p1",
    companyId: "sweettime",
    name: "Розовая луна с молочным чаем",
    category: "Молочный чай",
    color: "#ff9ec6",
    price: 350,
    sizes: drinkSizes,
    toppings: [
      { id: "t1", label: "Шарики тапиоки", priceDelta: 40 },
      { id: "t2", label: "Сырная пенка", priceDelta: 50 },
      { id: "t4", label: "Шарики с коричневым сахаром", priceDelta: 50 }
    ],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true,
    isBestSeller: true
  },
  {
    id: "p2",
    companyId: "sweettime",
    name: "Матча мятное облако",
    category: "Молочный чай",
    color: "#8fe5c7",
    price: 390,
    sizes: drinkSizes,
    toppings: [
      { id: "t1", label: "Шарики тапиоки", priceDelta: 40 },
      { id: "t5", label: "Пудинг", priceDelta: 45 }
    ],
    availableBranchIds: ["b1", "b2"],
    active: true,
    isNew: true
  },
  {
    id: "p3",
    companyId: "sweettime",
    name: "Латте с коричневым сахаром",
    category: "Кофе",
    color: "#b98560",
    price: 370,
    sizes: drinkSizes,
    toppings: [
      { id: "t4", label: "Шарики с коричневым сахаром", priceDelta: 50 },
      { id: "t6", label: "Кофейное желе", priceDelta: 40 }
    ],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true,
    isBestSeller: true
  },
  {
    id: "p4",
    companyId: "sweettime",
    name: "Персиковый жасмин",
    category: "Фруктовый чай",
    color: "#ffd39e",
    price: 330,
    sizes: drinkSizes,
    toppings: [
      { id: "t3", label: "Желе алоэ", priceDelta: 40 },
      { id: "t1", label: "Шарики тапиоки", priceDelta: 40 }
    ],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true,
    isNew: true
  },
  {
    id: "p5",
    companyId: "sweettime",
    name: "Какао фрост с шариками",
    category: "Кофе",
    color: "#7b4b35",
    price: 360,
    sizes: drinkSizes,
    toppings: [
      { id: "t6", label: "Кофейное желе", priceDelta: 40 },
      { id: "t2", label: "Сырная пенка", priceDelta: 50 }
    ],
    availableBranchIds: ["b1", "b3"],
    active: true
  },
  {
    id: "p6",
    companyId: "sweettime",
    name: "Манговый сливочный чай",
    category: "Фруктовый чай",
    color: "#ffc857",
    price: 340,
    sizes: drinkSizes,
    toppings: [
      { id: "t1", label: "Шарики тапиоки", priceDelta: 40 },
      { id: "t3", label: "Желе алоэ", priceDelta: 40 }
    ],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true
  },
  {
    id: "p7",
    companyId: "sweettime",
    name: "Колд брю ванильная роза",
    category: "Кофе",
    color: "#efb8c8",
    price: 330,
    sizes: drinkSizes,
    toppings: [
      { id: "t2", label: "Сырная пенка", priceDelta: 50 },
      { id: "t6", label: "Кофейное желе", priceDelta: 40 }
    ],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true
  },
  {
    id: "p8",
    companyId: "sweettime",
    name: "Клубничный моти-кап",
    category: "Десерты",
    color: "#ffb3c7",
    price: 290,
    sizes: [],
    toppings: [],
    availableBranchIds: ["b1", "b2", "b3"],
    active: true,
    isBestSeller: true
  }
];

// Новости-сторис и сезонные акции витрины SweetTime (мок-фоллбэк без API)
const sweettimeNews: NewsStory[] = [
  {
    id: "news-week-flavor",
    companyId: "sweettime",
    sortOrder: 10,
    isPublished: true,
    title: {
      ru: "Новый вкус недели",
      ky: "Аптанын жаңы даамы",
      en: "Flavor of the week"
    },
    body: {
      ru: "Попробуйте клубничный улун с воздушной сырной пенкой — только до воскресенья."
    },
    badge: { ru: "Новинка", ky: "Жаңы", en: "New" },
    accentColor: "#FF8FBD",
    visual: "sparkle",
    publishedAt: daysAgo(0),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  },
  {
    id: "news-manas",
    companyId: "sweettime",
    sortOrder: 20,
    isPublished: true,
    title: {
      ru: "Мы открылись на Манаса",
      ky: "Манас көчөсүндө ачылдык",
      en: "Now open on Manas"
    },
    body: {
      ru: "Новый филиал уже принимает заказы. Заходите ежедневно с 10:00 до 22:00."
    },
    badge: { ru: "Филиал" },
    accentColor: "#8FDCC4",
    visual: "storefront",
    publishedAt: daysAgo(3),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  },
  {
    id: "news-table-qr",
    companyId: "sweettime",
    sortOrder: 30,
    isPublished: true,
    title: { ru: "Заказ со столика" },
    body: {
      ru: "Отсканируйте QR в кафе, соберите напиток и не стойте в очереди."
    },
    badge: { ru: "Совет" },
    accentColor: "#FFC96B",
    visual: "qr",
    publishedAt: daysAgo(5),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  },
  {
    id: "news-double-points",
    companyId: "sweettime",
    sortOrder: 40,
    isPublished: true,
    title: { ru: "Двойные баллы" },
    body: {
      ru: "Каждый понедельник начисляем вдвое больше баллов за напитки с матчей."
    },
    badge: { ru: "Лояльность" },
    accentColor: "#A9D88E",
    visual: "loyalty",
    publishedAt: daysAgo(7),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  }
];

const sweettimePromotions: Promotion[] = [
  {
    id: "promo-duo",
    companyId: "sweettime",
    sortOrder: 10,
    active: true,
    title: { ru: "Утренний дуэт" },
    description: { ru: "Любой кофе и моти-кап за 520 сом" },
    code: "DUO",
    accentColor: "#FF8FBD"
  },
  {
    id: "promo-pearls",
    companyId: "sweettime",
    sortOrder: 20,
    active: true,
    title: { ru: "Час шариков" },
    description: { ru: "Бесплатная тапиока после 16:00" },
    code: "PEARLS",
    accentColor: "#8FDCC4"
  },
  {
    id: "promo-mint",
    companyId: "sweettime",
    sortOrder: 30,
    active: true,
    title: { ru: "Мятный понедельник" },
    description: { ru: "Вдвое больше баллов за зелёные напитки" },
    code: "MINT",
    accentColor: "#A9D88E"
  }
];

const sweettimeOrders: Order[] = [
  {
    id: "o-sw-1061",
    companyId: "sweettime",
    number: "SW-1061",
    items: [{ name: "Розовая луна (L, тапиока)", quantity: 1, unitPrice: 460 }],
    branchId: "b1",
    type: "pickup",
    status: "new",
    total: 460,
    createdAt: minutesAgo(4),
    customerName: "Айбек"
  },
  {
    id: "o-sw-1060",
    companyId: "sweettime",
    number: "SW-1060",
    items: [
      { name: "Манговый сливочный чай (M)", quantity: 1, unitPrice: 380 },
      { name: "Клубничный моти-кап", quantity: 1, unitPrice: 290 }
    ],
    branchId: "b3",
    type: "qr",
    status: "new",
    total: 670,
    createdAt: minutesAgo(7),
    customerName: "Нина"
  },
  {
    id: "o-sw-1059",
    companyId: "sweettime",
    number: "SW-1059",
    items: [
      { name: "Латте с коричневым сахаром (M)", quantity: 2, unitPrice: 410 }
    ],
    branchId: "b2",
    type: "scheduled",
    status: "preparing",
    total: 820,
    createdAt: minutesAgo(12),
    customerName: "Данияр"
  },
  {
    id: "o-sw-1058",
    companyId: "sweettime",
    number: "SW-1058",
    items: [
      { name: "Персиковый жасмин (S, алоэ)", quantity: 1, unitPrice: 370 },
      { name: "Колд брю ванильная роза (S)", quantity: 1, unitPrice: 330 }
    ],
    branchId: "b1",
    type: "pickup",
    status: "preparing",
    total: 700,
    createdAt: minutesAgo(18),
    customerName: "Айгерим"
  },
  {
    id: "o-sw-1057",
    companyId: "sweettime",
    number: "SW-1057",
    items: [{ name: "Розовая луна (L)", quantity: 1, unitPrice: 420 }],
    branchId: "b2",
    type: "pickup",
    status: "ready",
    total: 420,
    createdAt: minutesAgo(25),
    customerName: "Тимур"
  },
  {
    id: "o-sw-1056",
    companyId: "sweettime",
    number: "SW-1056",
    items: [
      { name: "Колд брю ванильная роза (M)", quantity: 1, unitPrice: 370 },
      { name: "Клубничный моти-кап", quantity: 1, unitPrice: 290 }
    ],
    branchId: "b3",
    type: "scheduled",
    status: "ready",
    total: 660,
    createdAt: minutesAgo(31),
    customerName: "Мээрим"
  },
  {
    id: "o-sw-1055",
    companyId: "sweettime",
    number: "SW-1055",
    items: [{ name: "Матча мятное облако (M)", quantity: 1, unitPrice: 430 }],
    branchId: "b1",
    type: "pickup",
    status: "done",
    total: 430,
    createdAt: minutesAgo(58),
    customerName: "Азамат"
  },
  {
    id: "o-sw-1054",
    companyId: "sweettime",
    number: "SW-1054",
    items: [
      { name: "Манговый сливочный чай (S)", quantity: 2, unitPrice: 340 }
    ],
    branchId: "b1",
    type: "qr",
    status: "done",
    total: 680,
    createdAt: minutesAgo(95),
    customerName: "Салтанат"
  },
  {
    id: "o-sw-1053",
    companyId: "sweettime",
    number: "SW-1053",
    items: [{ name: "Персиковый жасмин (S)", quantity: 1, unitPrice: 330 }],
    branchId: "b2",
    type: "pickup",
    status: "cancelled",
    total: 330,
    createdAt: minutesAgo(120),
    customerName: "Бакыт"
  },
  {
    id: "o-sw-1052",
    companyId: "sweettime",
    number: "SW-1052",
    items: [
      { name: "Розовая луна (S)", quantity: 1, unitPrice: 350 },
      { name: "Клубничный моти-кап", quantity: 1, unitPrice: 290 }
    ],
    branchId: "b3",
    type: "pickup",
    status: "done",
    total: 640,
    createdAt: yesterdayAt(18, 40),
    customerName: "Чолпон"
  },
  {
    id: "o-sw-1051",
    companyId: "sweettime",
    number: "SW-1051",
    items: [
      { name: "Латте с коричневым сахаром (S)", quantity: 1, unitPrice: 370 }
    ],
    branchId: "b1",
    type: "scheduled",
    status: "done",
    total: 370,
    createdAt: yesterdayAt(11, 15),
    customerName: "Айзада"
  }
];

// «Постоянные заказы» SweetTime: предоплаченный напиток к нужному времени
const sweettimeRecurring: RecurringOrder[] = [
  {
    id: "r-sw-1",
    companyId: "sweettime",
    customerName: "Данияр",
    productName: "Розовая луна с молочным чаем (M)",
    readyTime: "11:00",
    branchId: "b1",
    plan: "week",
    paidUntil: daysFromNow(4),
    active: true
  },
  {
    id: "r-sw-2",
    companyId: "sweettime",
    customerName: "Айгерим",
    productName: "Колд брю ванильная роза (S)",
    readyTime: "09:30",
    branchId: "b2",
    plan: "month",
    paidUntil: daysFromNow(18),
    active: true
  },
  {
    id: "r-sw-3",
    companyId: "sweettime",
    customerName: "Мээрим",
    productName: "Матча мятное облако (M)",
    readyTime: "14:00",
    branchId: "b3",
    plan: "week",
    paidUntil: daysFromNow(-2),
    active: false
  }
];

// ---------------------------------------------------------------------------
// CoffeeGo: контрастная компания — классическое кофейное меню, 2 филиала
// ---------------------------------------------------------------------------

const coffeegoBranches: Branch[] = [
  {
    id: "cg-b1",
    companyId: "coffeego",
    name: "CoffeeGo на Токтогула",
    address: "ул. Токтогула 98, Бишкек",
    hours: "08:00–20:00",
    phone: "+996 312 44 02 01",
    isOpen: true
  },
  {
    id: "cg-b2",
    companyId: "coffeego",
    name: "CoffeeGo на Юнусалиева",
    address: "ул. Юнусалиева 71, Бишкек",
    hours: "08:00–21:00",
    phone: "+996 312 44 02 02",
    isOpen: true
  }
];

const coffeeSizes = [
  { id: "s", label: "S (250 мл)", priceDelta: 0 },
  { id: "m", label: "M (350 мл)", priceDelta: 40 },
  { id: "l", label: "L (450 мл)", priceDelta: 70 }
];

const coffeeToppings = [
  { id: "ct1", label: "Доп. эспрессо-шот", priceDelta: 60 },
  { id: "ct2", label: "Альтернативное молоко", priceDelta: 50 },
  { id: "ct3", label: "Сироп", priceDelta: 40 }
];

const coffeegoProducts: Product[] = [
  {
    id: "cg-p1",
    companyId: "coffeego",
    name: "Эспрессо",
    category: "Кофе",
    color: "#4b2d22",
    price: 150,
    sizes: [
      { id: "single", label: "Одинарный", priceDelta: 0 },
      { id: "double", label: "Двойной", priceDelta: 60 }
    ],
    toppings: [],
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true
  },
  {
    id: "cg-p2",
    companyId: "coffeego",
    name: "Американо",
    category: "Кофе",
    color: "#6b4226",
    price: 180,
    sizes: coffeeSizes,
    toppings: [coffeeToppings[0], coffeeToppings[2]],
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true
  },
  {
    id: "cg-p3",
    companyId: "coffeego",
    name: "Капучино",
    category: "Кофе",
    color: "#b98560",
    price: 240,
    sizes: coffeeSizes,
    toppings: coffeeToppings,
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true,
    isBestSeller: true
  },
  {
    id: "cg-p4",
    companyId: "coffeego",
    name: "Латте",
    category: "Кофе",
    color: "#d4a373",
    price: 260,
    sizes: coffeeSizes,
    toppings: coffeeToppings,
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true,
    isBestSeller: true
  },
  {
    id: "cg-p5",
    companyId: "coffeego",
    name: "Флэт уайт",
    category: "Кофе",
    color: "#c69c7b",
    price: 270,
    sizes: [
      { id: "s", label: "S (250 мл)", priceDelta: 0 },
      { id: "m", label: "M (350 мл)", priceDelta: 40 }
    ],
    toppings: [coffeeToppings[1]],
    availableBranchIds: ["cg-b1"],
    active: true
  },
  {
    id: "cg-p6",
    companyId: "coffeego",
    name: "Раф ванильный",
    category: "Кофе",
    color: "#e8c9a0",
    price: 300,
    sizes: coffeeSizes,
    toppings: [coffeeToppings[2]],
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true,
    isNew: true
  },
  {
    id: "cg-p7",
    companyId: "coffeego",
    name: "Круассан с миндалём",
    category: "Выпечка",
    color: "#f0c987",
    price: 220,
    sizes: [],
    toppings: [],
    availableBranchIds: ["cg-b1", "cg-b2"],
    active: true
  }
];

const coffeegoOrders: Order[] = [
  {
    id: "o-cg-204",
    companyId: "coffeego",
    number: "CG-204",
    items: [
      { name: "Капучино (M)", quantity: 1, unitPrice: 280 },
      { name: "Круассан с миндалём", quantity: 1, unitPrice: 220 }
    ],
    branchId: "cg-b1",
    type: "pickup",
    status: "new",
    total: 500,
    createdAt: minutesAgo(3),
    customerName: "Эльдар"
  },
  {
    id: "o-cg-203",
    companyId: "coffeego",
    number: "CG-203",
    items: [{ name: "Латте (L, сироп)", quantity: 1, unitPrice: 370 }],
    branchId: "cg-b2",
    type: "qr",
    status: "preparing",
    total: 370,
    createdAt: minutesAgo(10),
    customerName: "Жылдыз"
  },
  {
    id: "o-cg-202",
    companyId: "coffeego",
    number: "CG-202",
    items: [{ name: "Американо (S)", quantity: 2, unitPrice: 180 }],
    branchId: "cg-b1",
    type: "pickup",
    status: "ready",
    total: 360,
    createdAt: minutesAgo(22),
    customerName: "Марат"
  },
  {
    id: "o-cg-201",
    companyId: "coffeego",
    number: "CG-201",
    items: [{ name: "Раф ванильный (M)", quantity: 1, unitPrice: 340 }],
    branchId: "cg-b2",
    type: "pickup",
    status: "done",
    total: 340,
    createdAt: minutesAgo(65),
    customerName: "Асель"
  },
  {
    id: "o-cg-200",
    companyId: "coffeego",
    number: "CG-200",
    items: [
      { name: "Флэт уайт (S)", quantity: 1, unitPrice: 270 },
      { name: "Эспрессо (двойной)", quantity: 1, unitPrice: 210 }
    ],
    branchId: "cg-b1",
    type: "scheduled",
    status: "done",
    total: 480,
    createdAt: minutesAgo(110),
    customerName: "Улан"
  },
  {
    id: "o-cg-199",
    companyId: "coffeego",
    number: "CG-199",
    items: [{ name: "Латте (S)", quantity: 1, unitPrice: 260 }],
    branchId: "cg-b1",
    type: "pickup",
    status: "cancelled",
    total: 260,
    createdAt: yesterdayAt(17, 20),
    customerName: "Каныкей"
  }
];

const coffeegoRecurring: RecurringOrder[] = [
  {
    id: "r-cg-1",
    companyId: "coffeego",
    customerName: "Марат",
    productName: "Капучино (M)",
    readyTime: "08:30",
    branchId: "cg-b1",
    plan: "month",
    paidUntil: daysFromNow(22),
    active: true
  }
];

const coffeegoNews: NewsStory[] = [
  {
    id: "cg-news-beans",
    companyId: "coffeego",
    sortOrder: 10,
    isPublished: true,
    title: { ru: "Новая обжарка недели", en: "New roast of the week" },
    body: {
      ru: "Эфиопия Иргачеффе — цитрус и жасмин. Попробуйте в фильтре или капучино."
    },
    badge: { ru: "Зерно" },
    accentColor: "#8FDCC4",
    visual: "sparkle",
    publishedAt: daysAgo(1),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  },
  {
    id: "cg-news-loyalty",
    companyId: "coffeego",
    sortOrder: 20,
    isPublished: true,
    title: { ru: "Шестой кофе — в подарок" },
    body: { ru: "Собирайте штампы в приложении и получайте напиток бесплатно." },
    badge: { ru: "Лояльность" },
    accentColor: "#FFC96B",
    visual: "loyalty",
    publishedAt: daysAgo(4),
    expiresAt: null,
    imageUrl: null,
    ctaLabel: null,
    ctaRoute: null
  }
];

const coffeegoPromotions: Promotion[] = [
  {
    id: "cg-promo-morning",
    companyId: "coffeego",
    sortOrder: 10,
    active: true,
    title: { ru: "Раннее утро" },
    description: { ru: "Американо −30% до 10:00" },
    code: "EARLY",
    accentColor: "#6b4226"
  },
  {
    id: "cg-promo-combo",
    companyId: "coffeego",
    sortOrder: 20,
    active: true,
    title: { ru: "Кофе + круассан" },
    description: { ru: "Комбо за 380 сом" },
    code: "COMBO",
    accentColor: "#d4a373"
  }
];

// ---------------------------------------------------------------------------
// Публичный API мок-слоя (единственная точка доступа к данным)
// ---------------------------------------------------------------------------

/**
 * Возвращает срез данных ОДНОЙ компании. Единственный способ получить
 * доменные данные в компонентах: всё уже отфильтровано по companyId.
 */
export function getCompanyData(companyId: string): CompanyData | null {
  const company = companies.find((c) => c.id === companyId);
  if (!company) return null;

  return {
    company,
    branches: sweettimeBranches
      .concat(coffeegoBranches)
      .filter((b) => b.companyId === companyId),
    products: sweettimeProducts
      .concat(coffeegoProducts)
      .filter((p) => p.companyId === companyId),
    orders: sweettimeOrders
      .concat(coffeegoOrders)
      .filter((o) => o.companyId === companyId),
    users: adminUsers
      .filter((u) => u.companyId === companyId)
      .map(({ password: _password, ...user }) => user),
    recurring: sweettimeRecurring
      .concat(coffeegoRecurring)
      .filter((r) => r.companyId === companyId),
    news: sweettimeNews
      .concat(coffeegoNews)
      .filter((n) => n.companyId === companyId)
      .sort((a, b) => a.sortOrder - b.sortOrder),
    promotions: sweettimePromotions
      .concat(coffeegoPromotions)
      .filter((p) => p.companyId === companyId)
      .sort((a, b) => a.sortOrder - b.sortOrder)
  };
}

/** Проверка демо-логина. Возвращает пользователя без пароля или null. */
export function authenticate(
  email: string,
  password: string
): AdminUser | null {
  const found = adminUsers.find(
    (u) =>
      u.email.toLowerCase() === email.trim().toLowerCase() &&
      u.password === password
  );
  if (!found) return null;
  const { password: _password, ...user } = found;
  return user;
}

/** Пользователь по id (для восстановления сессии из localStorage). */
export function getAdminUser(userId: string): AdminUser | null {
  const found = adminUsers.find((u) => u.id === userId);
  if (!found) return null;
  const { password: _password, ...user } = found;
  return user;
}

/** Подсказка на странице входа: список демо-аккаунтов. */
export function getDemoAccounts(): Array<{
  email: string;
  roleLabel: string;
  companyName: string;
}> {
  const roleLabels: Record<string, string> = {
    owner: "владелец",
    manager: "менеджер",
    barista: "бариста"
  };
  return adminUsers.map((u) => ({
    email: u.email,
    roleLabel: roleLabels[u.role] ?? u.role,
    companyName: companies.find((c) => c.id === u.companyId)?.name ?? ""
  }));
}
