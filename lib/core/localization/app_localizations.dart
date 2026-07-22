import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../shared/app_models.dart';

part 'auth_cart_checkout_localizations.dart';
part 'catalog_product_localizations.dart';
part 'profile_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations is not available in this context');
    return value!;
  }

  String _pick(String ru, String kg, String en) => switch (language) {
    AppLanguage.ru => ru,
    AppLanguage.ky => kg,
    AppLanguage.en => en,
  };

  String get home => _pick('Главная', 'Башкы бет', 'Home');
  String get catalog => _pick('Каталог', 'Каталог', 'Catalog');
  String get qr => 'QR';
  String get cart => _pick('Корзина', 'Себет', 'Cart');
  String get profile => _pick('Профиль', 'Профиль', 'Profile');
  String get languageLabel => _pick('Язык', 'Тил', 'Language');
  String get interfaceLanguage =>
      _pick('Язык приложения', 'Колдонмонун тили', 'App language');

  String get today => _pick('Сегодня', 'Бүгүн', 'Today');
  String get all => _pick('Все', 'Баары', 'All');
  String get seasonalOffers =>
      _pick('Сезонные акции', 'Сезондук акциялар', 'Seasonal offers');
  String get news => _pick('Новости', 'Жаңылыктар', 'News');
  String get whatsNew => _pick(
    'Узнайте, что у нас нового',
    'Биздеги жаңылыктар',
    'See what’s new',
  );
  String get openNews =>
      _pick('Открыть все новости', 'Бардык жаңылыктарды ачуу', 'Open all news');
  String get storyCollections =>
      _pick('Истории', 'Окуялар', 'Story collections');
  String get newsFeed =>
      _pick('Лента новостей', 'Жаңылыктар түрмөгү', 'News feed');
  String get newsFeedEmptyTitle =>
      _pick('Новостей пока нет', 'Азырынча жаңылык жок', 'No news yet');
  String get newsFeedEmptyMessage => _pick(
    'Свежие публикации появятся здесь.',
    'Жаңы жарыялар бул жерде чыгат.',
    'Fresh posts will appear here.',
  );
  String get collectionEmpty => _pick(
    'В этой подборке пока нет историй.',
    'Бул жыйнакта азырынча окуя жок.',
    'There are no stories in this collection yet.',
  );
  String get newsLoadFailed => _pick(
    'Не удалось загрузить новости.',
    'Жаңылыктар жүктөлбөй калды.',
    'Could not load news.',
  );
  String get retry => _pick('Повторить', 'Кайра аракет кылуу', 'Retry');
  String get readFullStory =>
      _pick('Читать полностью', 'Толук окуу', 'Read full story');
  String get playVideo => _pick('Воспроизвести', 'Ойнотуу', 'Play video');
  String get pauseVideo => _pick('Пауза', 'Тыныгуу', 'Pause video');
  String get popular => _pick('Популярное', 'Популярдуу', 'Popular');
  String get bestSellers =>
      _pick('Хиты продаж', 'Көп сатылгандар', 'Best sellers');
  String get newItems => _pick('Новинки', 'Жаңы', 'New');
  String get newOnMenu =>
      _pick('Новое в меню', 'Менюдагы жаңылыктар', 'New on the menu');
  String get branch => _pick('Филиал', 'Филиал', 'Branch');
  String get chooseBranch =>
      _pick('Выберите филиал', 'Филиалды тандаңыз', 'Choose a branch');
  String get pointsForEveryOrder => _pick(
    '✨ Баллы за каждый заказ',
    '✨ Ар бир заказ үчүн упайлар',
    '✨ Points with every order',
  );
  String get heroTitle => _pick(
    'Соберите напиток под себя',
    'Суусундукту өзүңүзгө ылайыктаңыз',
    'Make your drink your way',
  );
  String get heroBody => _pick(
    'Заберите в кафе к нужному времени или закажите по QR со столика.',
    'Кафеден керектүү убакта алып кетиңиз же столдон QR аркылуу заказ бериңиз.',
    'Pick it up at the right time or order from your table with QR.',
  );
  String get orderDrinks =>
      _pick('Заказать напитки', 'Суусундуктарды заказ кылуу', 'Order drinks');
  String footer(String appName) => _pick(
    '$appName — бабл-ти и кофе в Бишкеке.\n09:00–22:00, без выходных.',
    '$appName — Бишкектеги бабл-ти жана кофе.\n09:00–22:00, күн сайын.',
    '$appName — bubble tea and coffee in Bishkek.\n09:00–22:00, every day.',
  );
  String dataSource(bool apiConnected) => _pick(
    'данные: ${apiConnected ? 'сервер' : 'демо'}',
    'маалымат: ${apiConnected ? 'сервер' : 'демо'}',
    'data: ${apiConnected ? 'server' : 'demo'}',
  );
  String productAdded(String name) => _pick(
    '$name добавлен в корзину',
    '$name себетке кошулду',
    '$name added to cart',
  );
  String get orderAddedToCart => _pick(
    'Заказ добавлен в корзину',
    'Заказ себетке кошулду',
    'Order added to cart',
  );
  String get addToCart => _pick('В корзину', 'Себетке', 'Add to cart');
  String get newBadge => _pick('Новинка', 'Жаңы', 'New');
  String get hitBadge => _pick('Хит', 'Хит', 'Hit');

  String get close => _pick('Закрыть', 'Жабуу', 'Close');
  String get understood => _pick('Понятно', 'Түшүнүктүү', 'Got it');
  String get login => _pick('Войти', 'Кирүү', 'Sign in');
  String get myQr => _pick('Мой QR', 'Менин QR кодум', 'My QR');
  String get invite => _pick('Пригласить', 'Чакыруу', 'Invite');
  String get scan => _pick('Сканировать', 'Сканерлөө', 'Scan');
  String get qrGuestTitle => _pick(
    'QR доступен после входа',
    'QR киргенден кийин жеткиликтүү',
    'QR is available after sign-in',
  );
  String get qrGuestMessage => _pick(
    'После входа вы сможете показать карту лояльности и пригласить друга отдельной ссылкой.',
    'Киргенден кийин лоялдуулук картаңызды көрсөтүп, досуңузду өзүнчө шилтеме менен чакыра аласыз.',
    'After signing in, you can show your loyalty card and invite a friend with a separate link.',
  );
  String points(int value) => switch (language) {
    AppLanguage.ru => '$value ${_russianPointWord(value)}',
    AppLanguage.ky => '$value упай',
    AppLanguage.en => '$value ${value.abs() == 1 ? 'point' : 'points'}',
  };
  String get myQrDescription => _pick(
    'Покажите этот QR бариста для начисления или списания баллов.',
    'Упай кошуу же колдонуу үчүн бул QR кодду баристага көрсөтүңүз.',
    'Show this QR to a barista to earn or spend points.',
  );
  String inviteQrDescription(String appName) => _pick(
    'Покажите этот QR другу или отправьте ссылку. Она откроет $appName сразу на экране приглашения.',
    'Бул QR кодду досуңузга көрсөтүңүз же шилтемени жөнөтүңүз. Ал $appName колдонмосунда чакыруу экранын дароо ачат.',
    'Show this QR to a friend or send the link. It opens $appName directly on the invitation screen.',
  );
  String get shareInvite =>
      _pick('Поделиться приглашением', 'Чакырууну бөлүшүү', 'Share invitation');
  String get copyLink =>
      _pick('Копировать ссылку', 'Шилтемени көчүрүү', 'Copy link');
  String get linkCopied => _pick(
    'Ссылка приглашения скопирована',
    'Чакыруу шилтемеси көчүрүлдү',
    'Invitation link copied',
  );
  String inviteShareText(String appName, int points, String link) => _pick(
    'Установи $appName по моей ссылке и получи $points баллов на первый заказ: $link',
    '$appName колдонмосун менин шилтемем аркылуу орнотуп, биринчи заказга $points упай ал: $link',
    'Join $appName with my link and get $points points toward your first order: $link',
  );
  String get activateFriendCode => _pick(
    'Активировать код друга',
    'Достун кодун активдештирүү',
    'Activate a friend’s code',
  );
  String get invitedEyebrow => _pick('ПРИГЛАШЕНИЕ', 'ЧАКЫРУУ', 'INVITATION');
  String invitedTitle(String appName) => _pick(
    'Вас пригласили в $appName',
    'Сизди $appName колдонмосуна чакырышты',
    'You were invited to $appName',
  );
  String inviteFriendTitle(String appName) => _pick(
    'Пригласите друга в $appName',
    'Досуңузду $appName колдонмосуна чакырыңыз',
    'Invite a friend to $appName',
  );
  String invitedMessage(int points) => _pick(
    'Войдите или зарегистрируйтесь — после активации приглашения вы получите $points баллов. Ими можно оплатить часть первого заказа.',
    'Кириңиз же катталыңыз — чакыруу активдешкенден кийин $points упай аласыз. Аларды биринчи заказдын бир бөлүгүн төлөөгө колдонсоңуз болот.',
    'Sign in or create an account. After the invitation is activated, you will receive $points points toward your first order.',
  );
  String get signInAndGetPoints => _pick(
    'Войти и получить баллы',
    'Кирип, упай алуу',
    'Sign in and get points',
  );
  String get activatingInvite => _pick(
    'Активируем приглашение…',
    'Чакырууну активдештирип жатабыз…',
    'Activating invitation…',
  );
  String get goToHome => _pick('На главную', 'Башкы бетке', 'Go home');
  String get codeCopied =>
      _pick('Код скопирован', 'Код көчүрүлдү', 'Code copied');
  String referralBonus(int invited, int inviter) => _pick(
    'Другу — $invited баллов, вам — $inviter после его первого заказа',
    'Досуңузга — $invited упай, сизге — анын биринчи заказынан кийин $inviter упай',
    'Your friend gets $invited points; you get $inviter after their first order',
  );
  String get scanFriendQr => _pick(
    'Наведите камеру на QR друга',
    'Камераны досуңуздун QR кодуна багыттаңыз',
    'Point the camera at your friend’s QR',
  );
  String get cameraUnavailable => _pick(
    'Камера недоступна.\nВведите код друга вручную ниже.',
    'Камера жеткиликсиз.\nДосуңуздун кодун төмөндө кол менен жазыңыз.',
    'Camera unavailable.\nEnter your friend’s code manually below.',
  );
  String get enterFriendCode => _pick(
    'Введите код друга вручную',
    'Досуңуздун кодун кол менен жазыңыз',
    'Enter your friend’s code manually',
  );
  String get apply => _pick('Применить', 'Колдонуу', 'Apply');
  String get torchOn =>
      _pick('Включить вспышку', 'Жарыкты күйгүзүү', 'Turn flash on');
  String get torchOff =>
      _pick('Выключить вспышку', 'Жарыкты өчүрүү', 'Turn flash off');
  String get torchAuto => _pick(
    'Переключить автоматическую вспышку',
    'Автоматтык жарыкты которуу',
    'Toggle automatic flash',
  );
  String get torchUnavailable =>
      _pick('Вспышка недоступна', 'Жарык жеткиликсиз', 'Flash unavailable');
  String get torchError => _pick(
    'Не удалось переключить вспышку',
    'Жарыкты которуу мүмкүн болгон жок',
    'Could not toggle flash',
  );
  String get referralSafety => _pick(
    'Пригласивший может быть только один и только для новых клиентов — накрутить баллы взаимным сканированием не выйдет.',
    'Бир гана чакыруучу болот жана бул жаңы кардарлар үчүн гана — бири-бирин сканерлеп упай көбөйтүү мүмкүн эмес.',
    'Only one inviter can be linked, and only for a new customer; mutual scanning cannot inflate points.',
  );

  String get guestProfileTitle => _pick(
    'Войдите в аккаунт',
    'Аккаунтка кириңиз',
    'Sign in to your account',
  );
  String get guestProfileMessage => _pick(
    'Баллы, история заказов, любимые напитки и постоянный заказ доступны после входа.',
    'Упайлар, заказдар тарыхы, сүйүктүү суусундуктар жана туруктуу заказ киргенден кийин жеткиликтүү.',
    'Points, order history, favorite drinks and recurring orders are available after sign-in.',
  );
  String get greeting => _pick('Здравствуйте,', 'Саламатсызбы,', 'Hello,');
  String get languageHint => _pick(
    'Выбранный язык применяется ко всему интерфейсу и демо-контенту.',
    'Тандалган тил бардык интерфейске жана демо-контентке колдонулат.',
    'The selected language applies to the entire interface and demo content.',
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLanguage.values.any(
    (language) => language.locale.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(AppLanguage.fromLocale(locale)));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
