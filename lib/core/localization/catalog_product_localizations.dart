part of 'app_localizations.dart';

extension CatalogProductLocalizations on AppLocalizations {
  String catalogSubtitle(String appName) => _pick(
    'Соберите свой заказ $appName',
    '$appName менен өз заказыңызды түзүңүз',
    'Build your $appName order',
  );

  String get catalogSearchHint => _pick(
    'Поиск по напитку, топпингу или вкусу',
    'Суусундук, топпинг же даам боюнча издөө',
    'Search by drink, topping or flavour',
  );

  String get catalogEmptyTitle =>
      _pick('Ничего не найдено', 'Эч нерсе табылган жок', 'Nothing found');

  String get catalogEmptyMessage => _pick(
    'Попробуйте изменить запрос или категорию.',
    'Суроону же категорияны өзгөртүп көрүңүз.',
    'Try changing the search or category.',
  );

  String get favoritesFilter => _pick('Избранное', 'Сүйүктүүлөр', 'Favorites');

  String get favoritesFilterSemantics => _pick(
    'Показывать только избранные напитки',
    'Сүйүктүү суусундуктарды гана көрсөтүү',
    'Show favorite drinks only',
  );

  String get favoritesEmptyTitle => _pick(
    'В избранном пока пусто',
    'Сүйүктүүлөр азырынча бош',
    'No favorites yet',
  );

  String get favoritesEmptyMessage => _pick(
    'Нажмите на сердечко в карточке напитка, чтобы добавить его в избранное.',
    'Суусундукту сүйүктүүлөргө кошуу үчүн анын карточкасындагы жүрөкчөнү басыңыз.',
    'Tap the heart on a drink card to add it to your favorites.',
  );

  String get resetFilters =>
      _pick('Сбросить фильтры', 'Чыпкаларды тазалоо', 'Reset filters');

  String reviewCount(int count) => _pick(
    '$count ${_russianReviews(count)}',
    '$count сын-пикир',
    count == 1 ? '1 review' : '$count reviews',
  );

  String get bestSellerBadge =>
      _pick('Хит продаж', 'Көп сатылган', 'Best seller');
  String get sizeLabel => _pick('Размер', 'Өлчөм', 'Size');
  String get iceLabel => _pick('Лёд', 'Муз', 'Ice');
  String get sugarLabel => _pick('Сахар', 'Кант', 'Sugar');
  String get toppingsLabel => _pick('Топпинги', 'Топпингдер', 'Toppings');

  String iceLevelLabel(IceLevel level) => switch (level) {
    IceLevel.none => _pick('Без льда', 'Музсуз', 'No ice'),
    IceLevel.less => _pick('Меньше', 'Азыраак', 'Less'),
    IceLevel.regular => _pick('Обычно', 'Кадимки', 'Regular'),
    IceLevel.extra => _pick('Больше', 'Көбүрөөк', 'Extra'),
  };

  String addToCartWithPrice(String price) =>
      _pick('В корзину — $price', 'Себетке — $price', 'Add to cart — $price');

  String get productUnavailableAction => _pick(
    'Недоступно в этом филиале',
    'Бул филиалда жеткиликсиз',
    'Unavailable at this branch',
  );

  String productUnavailableAtBranch(String branchName) => _pick(
    'Этого напитка сейчас нет в «$branchName». Выберите другой филиал на главной.',
    '«$branchName» филиалында бул суусундук азыр жок. Башкы беттен башка филиалды тандаңыз.',
    'This drink is currently unavailable at “$branchName”. Choose another branch on Home.',
  );

  String get back => _pick('Назад', 'Артка', 'Back');
  String get addToFavorites =>
      _pick('Добавить в избранное', 'Сүйүктүүлөргө кошуу', 'Add to favourites');
  String get removeFromFavorites => _pick(
    'Удалить из избранного',
    'Сүйүктүүлөрдөн алып салуу',
    'Remove from favourites',
  );
}

String _russianReviews(int count) {
  final mod100 = count.abs() % 100;
  final mod10 = count.abs() % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'отзывов';
  if (mod10 == 1) return 'отзыв';
  if (mod10 >= 2 && mod10 <= 4) return 'отзыва';
  return 'отзывов';
}
