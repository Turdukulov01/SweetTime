part of 'app_localizations.dart';

extension AuthCartCheckoutLocalizations on AppLocalizations {
  String get copyCode => _pick('Скопировать код', 'Кодду көчүрүү', 'Copy code');

  String get authSection => _pick('АККАУНТ', 'АККАУНТ', 'ACCOUNT');

  String signInTitle(String appName) => _pick(
    'Войдите или зарегистрируйтесь',
    'Кириңиз же катталыңыз',
    'Sign in or register',
  );

  String get smsCodeTitle => _pick('Код из SMS', 'SMS коду', 'SMS code');

  String get authIntro => _pick(
    'Войдите через Google. Аккаунт SweetTime создаст backend после безопасной проверки Google ID token.',
    'Google аркылуу кириңиз. SweetTime аккаунтун backend Google ID token коопсуз текшергенден кийин түзөт.',
    'Continue with Google. SweetTime creates the account only after the backend securely verifies the Google ID token.',
  );

  String demoCodeSent(String phone, String code) => _pick(
    'Отправили код на $phone. Демо-код: $code.',
    '$phone номерине код жөнөтүлдү. Демо-код: $code.',
    'We sent a code to $phone. Demo code: $code.',
  );

  String get phoneNumber =>
      _pick('Номер телефона', 'Телефон номери', 'Phone number');
  String get kyrgyzPhoneFormatHint => _pick(
    'Введите 9 цифр после +996',
    '+996 кодунан кийин 9 цифра жазыңыз',
    'Enter 9 digits after +996',
  );
  String get requestCode => _pick('Получить код', 'Код алуу', 'Get code');
  String get confirmAndSignIn =>
      _pick('Подтвердить и войти', 'Тастыктап кирүү', 'Confirm and sign in');
  String get changePhoneNumber =>
      _pick('Изменить номер', 'Номерди өзгөртүү', 'Change number');
  String get phoneIncompleteError => _pick(
    'Введите ровно 9 цифр после +996',
    '+996 кодунан кийин так 9 цифра жазыңыз',
    'Enter exactly 9 digits after +996',
  );

  String invalidDemoCodeError(String code) => _pick(
    'Неверный код. Демо-код: $code',
    'Код туура эмес. Демо-код: $code',
    'Invalid code. Demo code: $code',
  );

  String get continueWithGoogle => _pick(
    'Продолжить с Google',
    'Google аркылуу улантуу',
    'Continue with Google',
  );

  String get googleSignInUnavailableMessage => _pick(
    'Вход через Google пока недоступен: нужно настроить OAuth для приложения и backend.',
    'Google аркылуу кирүү азырынча жеткиликтүү эмес: колдонмо жана backend үчүн OAuth жөндөөсү керек.',
    'Google sign-in is not available yet. OAuth must be configured for the app and backend.',
  );

  String get googleSignInFailed => _pick(
    'Не удалось войти через Google. Попробуйте ещё раз.',
    'Google аркылуу кирүү ишке ашкан жок. Кайра аракет кылыңыз.',
    'Could not sign in with Google. Please try again.',
  );

  String get googleSignInRejected => _pick(
    'Backend не принял Google-вход. Проверьте настройку OAuth.',
    'Backend Google аркылуу кирүүнү кабыл алган жок. OAuth жөндөөлөрүн текшериңиз.',
    'The backend rejected Google sign-in. Check the OAuth configuration.',
  );

  String get smsTemporarilyUnavailable => _pick(
    'Вход по SMS временно недоступен',
    'SMS аркылуу кирүү убактылуу жеткиликсиз',
    'SMS sign-in is temporarily unavailable',
  );

  String get smsUnavailableHint => _pick(
    'Мы подключим SMS-провайдера позже. Публичного демо-кода больше нет.',
    'SMS провайдерин кийин кошобуз. Ачык демо-код мындан ары жок.',
    'We will add an SMS provider later. The public demo code has been removed.',
  );

  String get contactPhoneTitle => _pick(
    'Добавьте телефон для связи',
    'Байланыш үчүн телефон кошуңуз',
    'Add a contact phone',
  );

  String get contactPhoneIntro => _pick(
    'Номер обязателен перед оформлением заказа. Он используется только для связи по заказу.',
    'Заказды тариздөөдөн мурун номер милдеттүү. Ал заказ боюнча байланыш үчүн гана колдонулат.',
    'A phone number is required before checkout and is used only to contact you about the order.',
  );

  String get contactPhoneUnverified => _pick(
    'SMS-подтверждение добавим позже. Пока номер не считается подтверждённым.',
    'SMS тастыктоону кийин кошобуз. Азырынча номер тастыкталган деп эсептелбейт.',
    'SMS verification will be added later. For now, this number is not verified.',
  );

  String get saveContactAndContinue =>
      _pick('Сохранить и продолжить', 'Сактап, улантуу', 'Save and continue');

  String get contactPhoneSaveFailed => _pick(
    'Не удалось сохранить номер. Проверьте соединение и попробуйте снова.',
    'Номер сакталган жок. Тармакты текшерип, кайра аракет кылыңыз.',
    'Could not save the phone number. Check your connection and try again.',
  );

  String get authProvidersDemoNotice => _pick(
    'Телефон после Google-входа сохраняется как контактный, без SMS-подтверждения.',
    'Google аркылуу киргенден кийин телефон SMS тастыктоосуз байланыш номери катары сакталат.',
    'After Google sign-in, the phone is stored as an unverified contact number.',
  );

  String get emptyCartTitle =>
      _pick('Корзина пуста', 'Себет бош', 'Cart is empty');
  String get emptyCartMessage => _pick(
    'Загляните в каталог — там точно найдётся что-то вкусное.',
    'Каталогду карап көрүңүз — ал жерден сөзсүз даамдуу нерсе табылат.',
    'Take a look at the catalog — you’re sure to find something delicious.',
  );
  String get goToCatalog =>
      _pick('Перейти в каталог', 'Каталогго өтүү', 'Go to catalog');
  String get orderSummary => _pick('Итого', 'Жыйынтык', 'Summary');
  String get promoCode => _pick('Промокод', 'Промокод', 'Promo code');
  String get usePoints =>
      _pick('Списать баллы', 'Упайларды колдонуу', 'Use points');

  String pointsSpendSummary(
    String available,
    String spend,
    int maxPercent,
  ) => _pick(
    'Доступно $available, спишется $spend (до $maxPercent% заказа)',
    'Жеткиликтүү: $available, колдонулат: $spend (заказдын $maxPercent% чейин)',
    '$available available, $spend will be used (up to $maxPercent% of the order)',
  );

  String get orderSubtotal =>
      _pick('Сумма заказа', 'Заказдын суммасы', 'Order subtotal');
  String get paidWithPoints =>
      _pick('Оплачено баллами', 'Упай менен төлөндү', 'Paid with points');
  String get amountDue => _pick('К оплате', 'Төлөнүүчү сумма', 'Amount due');

  String pointsEarnPreview(int points, int ratePercent) => _pick(
    'Начислим ${pointCount(points)} за этот заказ ($ratePercent%)',
    'Бул заказ үчүн ${pointCount(points)} кошулат ($ratePercent%)',
    'You’ll earn ${pointCount(points)} on this order ($ratePercent%)',
  );

  String checkoutWithTotal(String total) =>
      _pick('Оформить · $total', 'Заказ берүү · $total', 'Checkout · $total');

  String removeCartItem(String productName) => _pick(
    'Удалить «$productName» из корзины',
    '«$productName» себеттен алып салуу',
    'Remove “$productName” from cart',
  );

  String get checkoutTitle =>
      _pick('Оформление', 'Заказды тариздөө', 'Checkout');
  String get fulfillmentMethod =>
      _pick('Способ получения', 'Алуу жолу', 'Fulfillment method');
  String get prepareBy =>
      _pick('Приготовить к', 'Даяр болуучу убакыт', 'Prepare by');
  String get tableNumber =>
      _pick('Номер столика', 'Столдун номери', 'Table number');
  String get tableNumberExample =>
      _pick('Например, 7', 'Мисалы, 7', 'For example, 7');
  String get tableQrAutofillDemo => _pick(
    'В приложении номер подставится сам после сканирования QR на столике (демо).',
    'Колдонмодо столдогу QR кодду сканерлегенден кийин номер автоматтык түрдө коюлат (демо).',
    'In the app, the number will be filled in automatically after scanning the table QR (demo).',
  );
  String get payment => _pick('Оплата', 'Төлөм', 'Payment');
  String get paymentQrDemoNotice => _pick(
    'QR-код оплаты (демо). MBank/Элсом/О!Деньги подключим позже.',
    'Төлөмдүн QR коду (демо). MBank/Элсом/О!Деньги кийинчерээк туташтырылат.',
    'Payment QR code (demo). MBank/Elsom/O!Dengi will be connected later.',
  );
  String get comment => _pick('Комментарий', 'Комментарий', 'Comment');
  String get baristaCommentHint => _pick(
    'Пожелания бариста: теплее, меньше пенки, аллергии',
    'Баристага каалоолор: жылуураак, көбүгү азыраак, аллергиялар',
    'Notes for the barista: warmer, less foam, allergies',
  );
  String get payAndPlaceOrder => _pick(
    'Оплатить и разместить заказ',
    'Төлөп, заказ берүү',
    'Pay and place order',
  );
  String get orderCatalogUnavailable => _pick(
    'Не удалось проверить актуальный каталог. Обновите данные и повторите — корзина сохранена.',
    'Учурдагы каталогду текшерүү мүмкүн болгон жок. Маалыматты жаңыртып, кайра аракет кылыңыз — себет сакталды.',
    'Could not verify the current catalog. Refresh and try again — your cart is saved.',
  );
  String get orderSubmissionUnavailable => _pick(
    'Заказ не отправлен. Корзина сохранена — проверьте интернет и повторите попытку.',
    'Заказ жөнөтүлгөн жок. Себет сакталды — интернетти текшерип, кайра аракет кылыңыз.',
    'The order was not sent. Your cart is saved — check your connection and try again.',
  );

  String readyAt(String time) =>
      _pick('к $time', '$time убактысына', 'by $time');
  String tableReadyTime(String number) =>
      _pick('столик $number', '$number-стол', 'table $number');
  String readyInAboutMinutes(int minutes) => _pick(
    'через ~$minutes минут',
    '~$minutes мүнөттөн кийин',
    'in ~$minutes minutes',
  );

  String readyTimeLabel(OrderReadyTime value) => switch (value.kind) {
    OrderReadyTimeKind.asap => readyInAboutMinutes(10),
    OrderReadyTimeKind.scheduled => readyAt(value.value ?? ''),
    OrderReadyTimeKind.table => tableReadyTime(value.value ?? ''),
  };

  String cartItemsUnavailableAtBranch(String names) => _pick(
    '$names сейчас нет в этом филиале — выберите другой филиал или удалите напиток из корзины.',
    '$names азыр бул филиалда жок — башка филиалды тандаңыз же суусундукту себеттен алып салыңыз.',
    '$names are currently unavailable at this branch. Choose another branch or remove the drink from your cart.',
  );

  String orderAccepted(String number) => _pick(
    'Заказ $number принят',
    'Заказ $number кабыл алынды',
    'Order $number accepted',
  );

  String orderStatusAt({
    required String status,
    required String branch,
    required String readyTime,
  }) => _pick(
    'Статус: $status. $branch, $readyTime.',
    'Абалы: $status. $branch, $readyTime.',
    'Status: $status. $branch, $readyTime.',
  );

  String pointsEarned(int points) => _pick(
    'Начислено ${pointCount(points)}',
    '${pointCount(points)} кошулду',
    '${pointCount(points)} earned',
  );

  String friendReferralRewarded(int points) => _pick(
    '🎉 Ваш друг получил ${pointCount(points)} за приглашение',
    '🎉 Досуңуз чакыруу үчүн ${pointCount(points)} алды',
    '🎉 Your friend received ${pointCount(points)} for the invitation',
  );

  String get trackOrder =>
      _pick('Следить за заказом', 'Заказга көз салуу', 'Track order');
  String get goHome => _pick('На главную', 'Башкы бетке', 'Go home');

  String orderTypeLabel(OrderType value) => switch (value) {
    OrderType.pickup => _pick('Самовывоз', 'Өзү алып кетүү', 'Pickup'),
    OrderType.scheduled => _pick(
      'Ко времени',
      'Белгиленген убакытка',
      'Scheduled',
    ),
    OrderType.qrCafe => _pick('QR в кафе', 'Кафеде QR аркылуу', 'QR in café'),
  };

  String orderTypeHint(OrderType value) => switch (value) {
    OrderType.pickup => _pick(
      'Готовим сразу, ~10 минут',
      'Дароо даярдайбыз, ~10 мүнөт',
      'Ready in ~10 minutes',
    ),
    OrderType.scheduled => _pick(
      'Приготовим к выбранному часу',
      'Тандалган убакытка даярдайбыз',
      'Ready at your selected time',
    ),
    OrderType.qrCafe => _pick(
      'Со столика, принесем к вам',
      'Столдон заказ бериңиз, сизге алып барабыз',
      'Order from your table; we’ll bring it to you',
    ),
  };

  String paymentMethodLabel(PaymentMethod value) => switch (value) {
    PaymentMethod.mock => _pick('Демо-оплата', 'Демо төлөм', 'Demo payment'),
    PaymentMethod.cash => _pick('Наличные', 'Накталай', 'Cash'),
    PaymentMethod.qrDemo => _pick('QR-оплата', 'QR төлөм', 'QR payment'),
  };

  String paymentMethodHint(PaymentMethod value) => switch (value) {
    PaymentMethod.mock => _pick(
      'Тестовый платеж',
      'Тесттик төлөм',
      'Test payment',
    ),
    PaymentMethod.cash => _pick(
      'На кассе при получении',
      'Алып жатканда кассада',
      'Pay at the counter on pickup',
    ),
    PaymentMethod.qrDemo => _pick(
      'Демо QR-кода банка',
      'Банктын демо QR коду',
      'Demo bank QR code',
    ),
  };

  String orderStatusLabel(OrderStatus value) => switch (value) {
    OrderStatus.created => _pick('Создан', 'Түзүлдү', 'Created'),
    OrderStatus.awaitingPayment => _pick(
      'Ожидает оплаты',
      'Төлөм күтүлүүдө',
      'Awaiting payment',
    ),
    OrderStatus.paid => _pick('Оплачен', 'Төлөндү', 'Paid'),
    OrderStatus.accepted => _pick('Принят', 'Кабыл алынды', 'Accepted'),
    OrderStatus.preparing => _pick('Готовится', 'Даярдалып жатат', 'Preparing'),
    OrderStatus.ready => _pick(
      'Готов к выдаче',
      'Алып кетүүгө даяр',
      'Ready for pickup',
    ),
    OrderStatus.completed => _pick('Выдан', 'Берилди', 'Completed'),
    OrderStatus.cancelled => _pick('Отменен', 'Жокко чыгарылды', 'Cancelled'),
  };

  String referralResultTitle(ReferralResult value) => switch (value) {
    ReferralResult.success => _pick(
      'Код принят! +${Referral.invitedBonus} баллов',
      'Код кабыл алынды! +${Referral.invitedBonus} упай',
      'Code accepted! +${Referral.invitedBonus} points',
    ),
    ReferralResult.selfCode => _pick(
      'Это ваш код',
      'Бул сиздин кодуңуз',
      'This is your code',
    ),
    ReferralResult.alreadyInvited => _pick(
      'Вы уже приглашены',
      'Сиз буга чейин чакырылгансыз',
      'You’ve already been invited',
    ),
    ReferralResult.notNewUser => _pick(
      'Только для новых клиентов',
      'Жаңы кардарлар үчүн гана',
      'New customers only',
    ),
    ReferralResult.invalidCode => _pick(
      'Код не распознан',
      'Код таанылган жок',
      'Code not recognized',
    ),
  };

  String referralResultMessage(ReferralResult value) => switch (value) {
    ReferralResult.success => _pick(
      'Ваш друг получит ${Referral.inviterBonus} баллов после вашего первого выполненного заказа.',
      'Биринчи аяктаган заказыңыздан кийин досуңуз ${Referral.inviterBonus} упай алат.',
      'Your friend will receive ${Referral.inviterBonus} points after your first completed order.',
    ),
    ReferralResult.selfCode => _pick(
      'Пригласить самого себя нельзя.',
      'Өзүңүздү чакыра албайсыз.',
      'You cannot invite yourself.',
    ),
    ReferralResult.alreadyInvited => _pick(
      'Пригласивший может быть только один — привязка не меняется.',
      'Бир гана чакыруучу болот — байланышты өзгөртүү мүмкүн эмес.',
      'Only one inviter can be linked; it cannot be changed.',
    ),
    ReferralResult.notNewUser => _pick(
      'Приглашение работает до первого выполненного заказа.',
      'Чакыруу биринчи аяктаган заказга чейин иштейт.',
      'Invitation works only before your first completed order.',
    ),
    ReferralResult.invalidCode => _pick(
      'Проверьте 6-значный код друга и попробуйте ещё раз.',
      'Досуңуздун 6 орундуу кодун текшерип, кайра аракет кылыңыз.',
      'Check your friend’s 6-digit code and try again.',
    ),
  };

  String pointCount(int value) => points(value);

  String cartIceLevelLabel(IceLevel value) => switch (value) {
    IceLevel.none => _pick('без льда', 'музсуз', 'no ice'),
    IceLevel.less => _pick('меньше льда', 'азыраак муз', 'less ice'),
    IceLevel.regular => _pick('обычно', 'кадимки', 'regular ice'),
    IceLevel.extra => _pick('больше льда', 'көбүрөөк муз', 'extra ice'),
  };

  String cartModifiers(CartItem item) {
    final size = _modifierName(item.product.sizes, item.sizeId);
    final toppings = [
      for (final id in item.toppingIds)
        _modifierName(item.product.toppings, id),
    ];
    final sugar = _pick(
      'сахар ${item.sugarPercent}%',
      'кант ${item.sugarPercent}%',
      'sugar ${item.sugarPercent}%',
    );
    return [size, sugar, cartIceLevelLabel(item.ice), ...toppings].join(' • ');
  }

  String productName(Product value) => value.name.resolve(language);
  String branchName(Branch value) => value.name.resolve(language);
  String branchAddress(Branch value) => value.address.resolve(language);

  String _modifierName(List<ModifierOption> options, String id) {
    for (final option in options) {
      if (option.id == id) return option.name.resolve(language);
    }
    return id;
  }
}

String _russianPointWord(int value) {
  final lastTwo = value.abs() % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'баллов';
  return switch (value.abs() % 10) {
    1 => 'балл',
    2 || 3 || 4 => 'балла',
    _ => 'баллов',
  };
}
