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

  String get catalogBranchScope =>
      _pick('Меню филиала', 'Филиалдын менюсу', 'Branch menu');

  String myBranch(String branchName) => _pick(
    'Мой филиал · $branchName',
    'Менин филиалым · $branchName',
    'My branch · $branchName',
  );

  String get allBranches =>
      _pick('Все филиалы', 'Бардык филиалдар', 'All branches');

  String availableAtBranch(String branchName) => _pick(
    'Доступно в «$branchName»',
    '«$branchName» филиалында бар',
    'Available at “$branchName”',
  );

  String get unavailableAtBranchTitle => _pick(
    'Нет в выбранном филиале',
    'Тандалган филиалда жок',
    'Not at the selected branch',
  );

  String unavailableAtBranchHint(String branchName) => _pick(
    'Эти товары можно посмотреть, но для заказа нужно выбрать другой филиал вместо «$branchName».',
    'Бул товарларды көрүүгө болот, бирок заказ үчүн «$branchName» ордуна башка филиалды тандаңыз.',
    'You can still view these items, but choose another branch instead of “$branchName” to order them.',
  );

  String allBranchesHint(String branchName) => _pick(
    'Показаны все товары. Доступность и быстрая корзина проверяются для «$branchName».',
    'Бардык товарлар көрсөтүлдү. Жеткиликтүүлүк жана тез себет «$branchName» үчүн текшерилет.',
    'Showing every item. Availability and quick add are checked for “$branchName”.',
  );

  String get chooseAvailableBranch =>
      _pick('Выбрать филиал', 'Филиалды тандоо', 'Choose a branch');

  String chooseBranchForProduct(String productName) => _pick(
    'Где доступен «$productName»',
    '«$productName» кайда бар',
    'Where “$productName” is available',
  );

  String get branchDoesNotStockProduct => _pick(
    'В этом филиале товара нет',
    'Бул филиалда товар жок',
    'Not available at this branch',
  );

  String get branchClosed => _pick(
    'Филиал временно не принимает заказы',
    'Филиал убактылуу заказ кабыл албайт',
    'This branch is temporarily not accepting orders',
  );

  String branchSelectedForProduct(
    String branchName,
    String productName,
  ) => _pick(
    'Выбран «$branchName». Теперь «$productName» можно добавить в корзину.',
    '«$branchName» тандалды. Эми «$productName» товарын себетке кошсо болот.',
    '“$branchName” selected. You can now add “$productName” to the cart.',
  );

  String get productUnavailableEverywhere => _pick(
    'Сейчас товар недоступен во всех филиалах',
    'Товар азыр бардык филиалдарда жеткиликсиз',
    'This item is currently unavailable at every branch',
  );

  String get productAddFailed => _pick(
    'Не удалось добавить товар. Обновите каталог и попробуйте снова.',
    'Товар кошулган жок. Каталогду жаңыртып, кайра аракет кылыңыз.',
    'Could not add the item. Refresh the catalog and try again.',
  );

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

  String saveCartChangesWithPrice(String price) =>
      _pick('Сохранить — $price', 'Сактоо — $price', 'Save changes — $price');

  String get productUnavailableAction => _pick(
    'Недоступно в этом филиале',
    'Бул филиалда жеткиликсиз',
    'Unavailable at this branch',
  );

  String productUnavailableAtBranch(String branchName) => _pick(
    'Этого напитка сейчас нет в «$branchName». Выберите подходящий филиал здесь — настройки сохранятся.',
    '«$branchName» филиалында бул суусундук азыр жок. Ылайыктуу филиалды ушул жерден тандаңыз — жөндөөлөр сакталат.',
    'This drink is currently unavailable at “$branchName”. Choose a suitable branch here; your options will stay selected.',
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
