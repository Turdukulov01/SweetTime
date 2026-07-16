part of 'app_localizations.dart';

extension ProfileLocalizations on AppLocalizations {
  String get orderDetailsPromoCode =>
      _pick('Промокод', 'Промокод', 'Promo code');
  String get profileGuestMessage => _pick(
    'Баллы, история заказов и постоянный заказ доступны после входа.',
    'Упайлар, заказдар тарыхы жана туруктуу заказ киргенден кийин жеткиликтүү.',
    'Points, order history and recurring orders are available after sign-in.',
  );

  String get profileUseLightTheme => _pick(
    'Включить светлую тему',
    'Жарык теманы күйгүзүү',
    'Switch to light theme',
  );

  String get profileUseDarkTheme => _pick(
    'Включить тёмную тему',
    'Караңгы теманы күйгүзүү',
    'Switch to dark theme',
  );

  String get profileAddName =>
      _pick('Добавьте имя', 'Атыңызды кошуңуз', 'Add your name');

  String get profileEditAction =>
      _pick('Редактировать', 'Өзгөртүү', 'Edit profile');

  String get profileAvatarLabel =>
      _pick('Фото профиля', 'Профиль сүрөтү', 'Profile photo');

  String get profilePointsTitle => _pick('Баллы', 'Упайлар', 'Points');

  String profilePointsEntryHint(String balance) => _pick(
    '$balance · как начислять и тратить',
    '$balance · кантип топтоо жана колдонуу керек',
    '$balance · how to earn and spend',
  );

  String get profileHelpAccountTitle =>
      _pick('Помощь и аккаунт', 'Жардам жана аккаунт', 'Help and account');

  String get profileSupportTitle => _pick(
    'Связаться с поддержкой',
    'Колдоо кызматы менен байланышуу',
    'Contact support',
  );

  String get profileSupportSubtitle => _pick(
    'Способы связи и помощь',
    'Байланыш жолдору жана жардам',
    'Contact options and help',
  );

  String get profileFaqTitle => _pick(
    'Вопросы и ответы',
    'Суроолор жана жооптор',
    'Questions and answers',
  );

  String get profileFaqSubtitle => _pick(
    'Коротко о приложении',
    'Колдонмо тууралуу кыскача',
    'Quick answers about the app',
  );

  String get profileSupportDemoTitle => _pick(
    'Поддержка пока в демо-режиме',
    'Колдоо кызматы азырынча демо режимде',
    'Support is currently in demo mode',
  );

  String get profileSupportDemoBody => _pick(
    'Контакты появятся здесь после того, как владелец добавит их в настройках SweetTime. До этого мы не показываем вымышленные телефон или email.',
    'Байланыш маалыматтары ээси аларды SweetTime жөндөөлөрүнө кошкондон кийин бул жерде пайда болот. Ага чейин биз ойдон чыгарылган телефон же email көрсөтпөйбүз.',
    'Contact details will appear here after the owner adds them in SweetTime settings. Until then, we do not show made-up phone numbers or email addresses.',
  );

  String get profileSupportChat =>
      _pick('Чат с поддержкой', 'Колдоо кызматынын чаты', 'Support chat');

  String get profileSupportPhone => _pick('Позвонить', 'Чалуу', 'Call support');

  String get profileSupportUnavailable => _pick(
    'Будет доступно после настройки',
    'Жөндөөдөн кийин жеткиликтүү болот',
    'Available after setup',
  );

  String get profileFaqPointsQuestion => _pick(
    'Как начисляются и списываются баллы?',
    'Упайлар кантип кошулат жана колдонулат?',
    'How do I earn and spend points?',
  );

  String get profileFaqPointsAnswer => _pick(
    'Баллы начисляются после заказа. Ими можно оплатить часть следующего заказа. Текущие правила и срок действия всегда показаны в разделе «Баллы».',
    'Упайлар заказдан кийин кошулат. Алар менен кийинки заказдын бир бөлүгүн төлөөгө болот. Учурдагы эрежелер жана жарактуулук мөөнөтү «Упайлар» бөлүмүндө көрсөтүлөт.',
    'Points are added after an order and can cover part of a future order. Current rules and expiration details are always shown in the Points section.',
  );

  String get profileFaqOrderQuestion => _pick(
    'Где посмотреть или повторить заказ?',
    'Заказды кайдан көрүүгө же кайталоого болот?',
    'Where can I view or repeat an order?',
  );

  String get profileFaqOrderAnswer => _pick(
    'История находится в профиле. У сохранённого заказа нажмите «Повторить», затем проверьте корзину, доступность товаров и итоговую сумму.',
    'Тарых профилде жайгашкан. Сакталган заказдан «Кайталоо» баскычын басып, андан кийин себетти, товарлардын жеткиликтүүлүгүн жана жалпы сумманы текшериңиз.',
    'Order history is in your profile. Tap Order again on a saved order, then review the cart, item availability and total.',
  );

  String get profileFaqQrQuestion => _pick(
    'Для чего нужен QR?',
    'QR эмне үчүн керек?',
    'What is the QR code for?',
  );

  String get profileFaqQrAnswer => _pick(
    'Покажите личный QR бариста для начисления или списания баллов. Через вкладку QR также можно привязать код пригласившего, если аккаунт новый.',
    'Упай кошуу же колдонуу үчүн жеке QR кодуңузду баристага көрсөтүңүз. Аккаунт жаңы болсо, QR бөлүмү аркылуу чакырган адамдын кодун да байланыштыра аласыз.',
    'Show your personal QR to the barista to earn or spend points. New accounts can also link an inviter code from the QR tab.',
  );

  String get profileFaqEditQuestion => _pick(
    'Как изменить данные профиля?',
    'Профиль маалыматын кантип өзгөртүүгө болот?',
    'How do I change my profile details?',
  );

  String get profileFaqEditAnswer => _pick(
    'Нажмите «Редактировать» в верхней карточке профиля. Можно изменить имя, фамилию, дату рождения и фото. В прототипе фото хранится только в текущем сеансе.',
    'Профилдин жогорку карточкасындагы «Өзгөртүү» баскычын басыңыз. Аты-жөнүңүздү, туулган күнүңүздү жана сүрөтүңүздү өзгөртө аласыз. Прототипте сүрөт ушул сеанста гана сакталат.',
    'Tap Edit profile in the top profile card. You can change your first name, last name, birth date and photo. In the prototype, the photo lasts only for the current session.',
  );

  String get profileFaqDeleteQuestion => _pick(
    'Что произойдёт при удалении аккаунта?',
    'Аккаунт өчүрүлгөндө эмне болот?',
    'What happens if I delete my account?',
  );

  String get profileFaqDeleteAnswer => _pick(
    'В демо-режиме удаляются данные профиля, баллы и постоянный заказ. Для реального запуска потребуется серверное удаление данных и подтверждение операции.',
    'Демо режимде профиль маалыматы, упайлар жана туруктуу заказ өчүрүлөт. Чыныгы ишке киргизүүдө маалыматтарды серверден өчүрүү жана аракетти ырастоо талап кылынат.',
    'Demo mode removes profile data, points and the recurring order. A production release will require server-side deletion and operation confirmation.',
  );

  String get profileEditTitle =>
      _pick('Редактирование профиля', 'Профилди өзгөртүү', 'Edit profile');

  String get profileFirstNameLabel => _pick('Имя', 'Аты', 'First name');

  String get profileLastNameLabel => _pick('Фамилия', 'Фамилиясы', 'Last name');

  String get profileFirstNameRequired =>
      _pick('Введите имя', 'Атыңызды жазыңыз', 'Enter your first name');

  String get profileLastNameRequired =>
      _pick('Введите фамилию', 'Фамилияңызды жазыңыз', 'Enter your last name');

  String get profileBirthDateLabel =>
      _pick('Дата рождения', 'Туулган күнү', 'Birth date');

  String get profileBirthDateOptional => _pick(
    'Не указана (необязательно)',
    'Көрсөтүлгөн эмес (милдеттүү эмес)',
    'Not set (optional)',
  );

  String get profileBirthDateClear => _pick(
    'Очистить дату рождения',
    'Туулган күндү тазалоо',
    'Clear birth date',
  );

  String profileBirthDateValue(DateTime value) => _profileLocalizedDate(value);

  String get profileAvatarGallery =>
      _pick('Выбрать из галереи', 'Галереядан тандоо', 'Choose from gallery');

  String get profileAvatarCamera =>
      _pick('Сфотографировать', 'Сүрөткө тартуу', 'Take a photo');

  String get profileAvatarRemove =>
      _pick('Удалить фото', 'Сүрөттү өчүрүү', 'Remove photo');

  String get profileAvatarDemoNotice => _pick(
    'Фото хранится в вашем профиле на сервере и будет доступно после повторного входа.',
    'Сүрөт серверде профилиңизде сакталат жана кайра киргенде жеткиликтүү болот.',
    'The photo is stored with your server profile and remains available after you sign in again.',
  );

  String get profileAvatarPickerError => _pick(
    'Не удалось открыть камеру или галерею. Проверьте разрешение и попробуйте снова.',
    'Камераны же галереяны ачуу мүмкүн болгон жок. Уруксатты текшерип, кайра аракет кылыңыз.',
    'Could not open the camera or gallery. Check permission and try again.',
  );

  String get profileAvatarUploadError => _pick(
    'Не удалось сохранить фото на сервере. Проверьте подключение и попробуйте снова.',
    'Сүрөттү серверге сактоо мүмкүн болгон жок. Байланышты текшерип, кайра аракет кылыңыз.',
    'Could not save the photo to the server. Check your connection and try again.',
  );

  String get profileSave => _pick('Сохранить', 'Сактоо', 'Save');

  String get profileSaving => _pick('Сохраняем…', 'Сакталууда…', 'Saving…');

  String get profileSaved =>
      _pick('Профиль обновлён', 'Профиль жаңыртылды', 'Profile updated');

  String get profileBonusBalance =>
      _pick('Бонусный баланс', 'Бонустук баланс', 'Bonus balance');

  String get profileLoyaltyRules =>
      _pick('Как работают баллы', 'Упайлар кандай иштейт', 'How points work');

  String profilePointValueRule(String points, String money) =>
      _pick('$points = $money', '$points = $money', '$points = $money');

  String profileEarnRule(int percent) => _pick(
    'Начисляем $percent% от каждого заказа',
    'Ар бир заказдан $percent% упай кошобуз',
    'Earn $percent% back on every order',
  );

  String profileSpendRule(int percent) => _pick(
    'Баллами можно оплатить до $percent% заказа',
    'Заказдын $percent% чейин упай менен төлөсө болот',
    'Pay for up to $percent% of an order with points',
  );

  String profileExpiryRule({required int months}) => _pick(
    'Баллы действуют $months месяцев с даты начисления',
    'Упайлар кошулган күндөн тартып $months ай жарактуу',
    'Points are valid for $months months from the date they are earned',
  );

  String get profileInviteFriend =>
      _pick('Пригласите друга', 'Досуңузду чакырыңыз', 'Invite a friend');

  String profileReferralDescription({
    required String invitedPoints,
    required String inviterPoints,
  }) => _pick(
    'Другу — $invitedPoints после регистрации по вашему коду, '
        'вам — $inviterPoints после его первого завершённого заказа. '
        'Ваш QR — во вкладке «QR» внизу.',
    'Досуңуз сиздин кодуңуз менен катталгандан кийин $invitedPoints алат, '
        'ал эми сиз анын биринчи аяктаган заказынан кийин $inviterPoints аласыз. '
        'Сиздин QR кодуңуз төмөнкү «QR» бөлүмүндө.',
    'Your friend gets $invitedPoints after signing up with your code, '
        'and you get $inviterPoints after their first completed order. '
        'Your QR is in the “QR” tab below.',
  );

  String get profileOrderHistory =>
      _pick('История заказов', 'Заказдар тарыхы', 'Order history');

  String get profileOpenOrderHistory => _pick(
    'Открыть историю заказов',
    'Заказдар тарыхын ачуу',
    'Open order history',
  );

  String get profileOrderHistoryEmptyCompact =>
      _pick('Заказов пока нет', 'Азырынча заказ жок', 'No orders yet');

  String profileOrderHistorySummary(int count, String latestStatus) => _pick(
    '$count заказов · последний: $latestStatus',
    '$count заказ · акыркысы: $latestStatus',
    '$count orders · latest: $latestStatus',
  );

  String get orderHistoryManage =>
      _pick('Выбрать заказы', 'Заказдарды тандоо', 'Select orders');

  String get orderHistoryExitSelection =>
      _pick('Завершить выбор', 'Тандоону бүтүрүү', 'Finish selection');

  String orderHistorySelected(int count) =>
      _pick('Выбрано: $count', 'Тандалды: $count', '$count selected');

  String get orderHistorySelectAll =>
      _pick('Выбрать все', 'Баарын тандоо', 'Select all');

  String get orderHistoryClearSelection =>
      _pick('Снять выбор', 'Тандоону алып салуу', 'Clear selection');

  String get orderHistoryHideSelected => _pick(
    'Убрать выбранные из истории',
    'Тандалгандарды тарыхтан алып салуу',
    'Remove selected from history',
  );

  String get orderHistoryHideTitle =>
      _pick('Убрать заказы?', 'Заказдарды алып саласызбы?', 'Remove orders?');

  String orderHistoryHideBody(int count) => _pick(
    '$count заказов исчезнут только с этого устройства. На сервере и в админке они сохранятся.',
    '$count заказ ушул түзмөктөн гана жашырылат. Серверде жана админкада алар сакталат.',
    '$count orders will be hidden only on this device. They remain on the server and in admin.',
  );

  String get orderHistoryHideConfirm => _pick('Убрать', 'Алып салуу', 'Remove');

  String get orderHistoryHideCancel =>
      _pick('Отмена', 'Жокко чыгаруу', 'Cancel');

  String orderHistoryHidden(int count) => _pick(
    '$count заказов убрано с устройства',
    '$count заказ түзмөктөн алынды',
    '$count orders removed from this device',
  );

  String get orderHistoryRefresh => _pick(
    'Обновить историю заказов',
    'Заказдар тарыхын жаңыртуу',
    'Refresh order history',
  );

  String get orderHistoryRefreshFailed => _pick(
    'Не удалось обновить историю. Последние загруженные заказы сохранены.',
    'Тарыхты жаңыртуу мүмкүн болгон жок. Акыркы жүктөлгөн заказдар сакталды.',
    'Could not refresh history. Your last loaded orders are still here.',
  );

  String get orderHistoryRetry =>
      _pick('Повторить', 'Кайра аракет кылуу', 'Retry');

  String get orderHistorySessionExpired => _pick(
    'Сессия завершена. Войдите снова, чтобы обновить заказы.',
    'Сессия бүттү. Заказдарды жаңыртуу үчүн кайра кириңиз.',
    'Your session ended. Sign in again to refresh orders.',
  );

  String profileOrderItemsCount(int count) =>
      _pick('$count позиций', '$count позиция', '$count items');

  String get orderDetailsTitle =>
      _pick('Детали заказа', 'Заказдын чоо-жайы', 'Order details');

  String get orderDetailsDate => _pick('Дата', 'Дата', 'Date');
  String get orderDetailsBranch => _pick('Филиал', 'Филиал', 'Branch');
  String get orderDetailsType => _pick('Получение', 'Алуу', 'Fulfillment');
  String get orderDetailsReadyTime => _pick('Время', 'Убакыт', 'Ready time');
  String get orderDetailsPayment => _pick('Оплата', 'Төлөм', 'Payment');
  String get orderDetailsStatus => _pick('Статус', 'Абалы', 'Status');
  String get orderDetailsCustomerPhone =>
      _pick('Телефон клиента', 'Кардардын телефону', 'Customer phone');
  String get orderDetailsItems =>
      _pick('Состав заказа', 'Заказдын курамы', 'Items');
  String get orderDetailsTotal => _pick('Итого', 'Жалпы', 'Total');
  String get orderDetailsPointsUsed =>
      _pick('Списано баллов', 'Колдонулган упай', 'Points used');
  String get orderDetailsPointsEarned =>
      _pick('Начислено баллов', 'Кошулган упай', 'Points earned');
  String get orderDetailsComment =>
      _pick('Комментарий', 'Комментарий', 'Comment');
  String get orderDetailsDateUnavailable =>
      _pick('Дата не сохранена', 'Дата сакталган эмес', 'Date unavailable');

  String orderDetailsQuantity(int quantity) =>
      _pick('Количество: $quantity', 'Саны: $quantity', 'Quantity: $quantity');

  String orderDetailsUnitPrice(String price) =>
      _pick('$price за единицу', 'Бир даанасы $price', '$price each');

  String get orderDetailsSnapshotProduct => _pick(
    'Товар больше не представлен в текущем каталоге. Показаны сохранённые данные заказа.',
    'Товар азыркы каталогдо жок. Заказда сакталган маалымат көрсөтүлдү.',
    'This item is no longer in the current catalog. Saved order details are shown.',
  );

  String orderDetailsUnknownTopping(String id) =>
      _pick('Добавка $id', '$id кошумчасы', 'Topping $id');

  String get profileOrderHistoryEmpty => _pick(
    'Здесь появятся ваши заказы после первого оформления.',
    'Биринчи заказдан кийин заказдарыңыз ушул жерде көрүнөт.',
    'Your orders will appear here after you place your first one.',
  );

  String get profileRepeatOrder =>
      _pick('Повторить', 'Кайталоо', 'Order again');

  String get profileLegacyOrderRepeatUnavailable => _pick(
    'Этот старый заказ нельзя повторить автоматически.',
    'Бул эски заказды автоматтык түрдө кайталоо мүмкүн эмес.',
    'This older order cannot be repeated automatically.',
  );

  String get profileRepeatNeedsServerCatalog => _pick(
    'Подключитесь к серверу, чтобы безопасно повторить заказ.',
    'Заказды коопсуз кайталоо үчүн серверге туташыңыз.',
    'Connect to the server to repeat this order safely.',
  );

  String get profileRepeatSelectionUnavailable => _pick(
    'Состав заказа изменился или товар недоступен в выбранном филиале. Корзина не изменена.',
    'Заказдын курамы өзгөргөн же товар тандалган филиалда жеткиликсиз. Себет өзгөргөн жок.',
    'This order changed or is unavailable at the selected branch. Your cart was not changed.',
  );

  String profileUnknownBranch(String branchId) => _pick(
    'Филиал недоступен ($branchId)',
    'Филиал жеткиликсиз ($branchId)',
    'Branch unavailable ($branchId)',
  );

  String get profileAddresses => _pick('Адреса', 'Даректер', 'Addresses');

  String get profileHomeAddressLabel => _pick('Дом', 'Үй', 'Home');

  String get profileHomeAddress => _pick(
    'мкр. Джал 23, кв. 12, Бишкек',
    'Жал кичи району 23, 12-батир, Бишкек',
    '23 Zhal microdistrict, apt. 12, Bishkek',
  );

  String get profileOfficeAddressLabel => _pick('Офис', 'Кеңсе', 'Office');

  String get profileOfficeAddress => _pick(
    'пр. Манаса 40, 4 этаж, Бишкек',
    'Манас проспекти 40, 4-кабат, Бишкек',
    '40 Manas Ave., 4th floor, Bishkek',
  );

  String get profileFavoriteDrinks =>
      _pick('Любимые напитки', 'Сүйүктүү суусундуктар', 'Favorite drinks');

  String get profileLogout => _pick('Выйти', 'Чыгуу', 'Sign out');

  String get profileDeleteAccount =>
      _pick('Удалить аккаунт', 'Аккаунтту өчүрүү', 'Delete account');

  String get profileDeleteAccountTitle =>
      _pick('Удалить аккаунт?', 'Аккаунтту өчүрөсүзбү?', 'Delete account?');

  String get profileDeleteAccountBody => _pick(
    'Профиль, телефон, фото, баллы, избранное и постоянный заказ будут '
        'удалены с сервера. История покупок останется только в обезличенном '
        'виде. Это действие необратимо.',
    'Профиль, телефон, сүрөт, упайлар, тандалмалар жана туруктуу заказ '
        'серверден өчүрүлөт. Сатып алуулар тарыхы аты-жөнү жок гана сакталат. '
        'Бул аракетти артка кайтаруу мүмкүн эмес.',
    'Your profile, phone, photo, points, favorites, and recurring order will '
        'be removed from the server. Purchase records will remain anonymous. '
        'This action cannot be undone.',
  );

  String get profileCancelDelete => _pick('Отмена', 'Жокко чыгаруу', 'Cancel');

  String get profileConfirmDelete => _pick('Удалить', 'Өчүрүү', 'Delete');

  String get profileDeleteAccountFailed => _pick(
    'Не удалось удалить аккаунт. Проверьте интернет и повторите попытку.',
    'Аккаунт өчүрүлгөн жок. Интернетти текшерип, кайра аракет кылыңыз.',
    'Could not delete the account. Check your connection and try again.',
  );

  String get profileDeleteSessionExpired => _pick(
    'Сессия завершилась. Войдите снова, затем повторите удаление аккаунта.',
    'Сеанс аяктады. Кайра кирип, аккаунтту өчүрүүнү кайталаңыз.',
    'Your session expired. Sign in again, then retry account deletion.',
  );

  String get recurringOrderTitle =>
      _pick('Постоянный заказ', 'Туруктуу заказ', 'Recurring order');

  String get recurringIntro => _pick(
    'Выберите любимые напитки, время и филиал — и оплатите вперёд. '
        'Каждый день заказ будет готов к нужному часу без очереди.',
    'Сүйүктүү суусундуктарды, убакытты жана филиалды тандап, '
        'алдын ала төлөңүз. Заказ күн сайын керектүү убакта кезексиз даяр болот.',
    'Choose your favorite drinks, time, and branch, then pay in advance. '
        'Your order will be ready at the right time every day, with no queue.',
  );

  String get recurringConfigure => _pick(
    'Настроить постоянный заказ',
    'Туруктуу заказды жөндөө',
    'Set up a recurring order',
  );

  String recurringActiveLabel(RecurringPlan plan) => _pick(
    'Активен · ${recurringPlanLabel(plan)}',
    'Активдүү · ${recurringPlanLabel(plan)}',
    'Active · ${recurringPlanLabel(plan)}',
  );

  String recurringSchedule(String time, String branch) => _pick(
    'Каждый день к $time · $branch',
    'Күн сайын $time убактысына · $branch',
    'Every day by $time · $branch',
  );

  String recurringPaidUntil(DateTime value) {
    final date = _profileLocalizedDate(value);
    return _pick(
      'Оплачено до $date',
      '$date чейин төлөндү',
      'Paid through $date',
    );
  }

  String get recurringPaidUntilUnavailable => _pick(
    'Срок оплаты недоступен',
    'Төлөм мөөнөтү жеткиликсиз',
    'Paid-through date unavailable',
  );

  String get recurringCancel => _pick('Отменить', 'Токтотуу', 'Cancel');

  String recurringProductUnavailable(String productId) => _pick(
    'Товар недоступен ($productId)',
    'Товар жеткиликсиз ($productId)',
    'Product unavailable ($productId)',
  );

  String get recurringCancelFailed => _pick(
    'Не удалось отменить постоянный заказ. Проверьте подключение и повторите.',
    'Туруктуу заказды токтотуу мүмкүн болгон жок. Байланышты текшерип, кайталаңыз.',
    'Could not cancel the recurring order. Check your connection and try again.',
  );

  String get recurringSheetIntro => _pick(
    'Оплатите любимые напитки вперёд — готовим каждый день к нужному часу.',
    'Сүйүктүү суусундуктарды алдын ала төлөңүз — күн сайын керектүү убакта даярдайбыз.',
    'Pay for your favorite drinks in advance, and we will prepare them at the right time every day.',
  );

  String get recurringDrinksStep => _pick(
    '1. Напитки или комбо',
    '1. Суусундуктар же комбо',
    '1. Drinks or combo',
  );

  String get recurringReadyTimeStep =>
      _pick('2. Время готовности', '2. Даяр болуу убактысы', '2. Ready time');

  String get recurringBranchStep =>
      _pick('3. Филиал', '3. Филиал', '3. Branch');

  String get recurringPrepaymentStep =>
      _pick('4. Предоплата', '4. Алдын ала төлөм', '4. Prepayment');

  String recurringReadyAt(String time) =>
      _pick('Готов к $time', '$time убактысына даяр', 'Ready by $time');

  String recurringPlanLabel(RecurringPlan plan) => switch (plan) {
    RecurringPlan.single => _pick('Один день', 'Бир күн', 'One day'),
    RecurringPlan.week => _pick('Неделя', 'Бир жума', 'One week'),
    RecurringPlan.month => _pick('Месяц', 'Бир ай', 'One month'),
  };

  String recurringPlanHint(RecurringPlan plan) => switch (plan) {
    RecurringPlan.single => _pick(
      'Разовая предоплата',
      'Бир жолку алдын ала төлөм',
      'One-time prepayment',
    ),
    RecurringPlan.week => _pick('7 дней', '7 күн', '7 days'),
    RecurringPlan.month => _pick('30 дней', '30 күн', '30 days'),
  };

  String get recurringEnabledDemo => _pick(
    'Постоянный заказ включён (демо)',
    'Туруктуу заказ иштетилди (демо)',
    'Recurring order enabled (demo)',
  );

  String get recurringSaveFailed => _pick(
    'Не удалось сохранить постоянный заказ. Корзина и оплата не изменены.',
    'Туруктуу заказды сактоо мүмкүн болгон жок. Себет жана төлөм өзгөргөн жок.',
    'Could not save the recurring order. Your cart and payment were not changed.',
  );

  String recurringPayAndEnable(String total) => _pick(
    'Оплатить $total и включить (демо)',
    '$total төлөп, иштетүү (демо)',
    'Pay $total and enable (demo)',
  );

  String _profileLocalizedDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return _pick(
      '$day.$month.${value.year}',
      '$day.$month.${value.year}',
      '${value.year}-$month-$day',
    );
  }
}
