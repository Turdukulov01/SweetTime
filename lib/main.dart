import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/localization/app_localizations.dart';
import 'core/branding_store.dart';
import 'core/referral_invite.dart';
import 'core/theme/app_theme.dart';
import 'shared/app_state.dart';
import 'shared/app_models.dart';
import 'shared/widgets/branded_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Пуши — некритичный путь: отсутствие/ошибка google-services.json или
  // Firebase не должны ронять запуск приложения. На Android опции читаются из
  // google-services.json автоматически, поэтому options здесь не передаём.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Без Firebase приложение работает как раньше, просто без push-уведомлений.
  }
  final cachedBranding = await SharedPreferencesBrandingStore(
    companyId: 'sweettime',
  ).read();
  runApp(
    ProviderScope(
      overrides: [initialBrandingProvider.overrideWithValue(cachedBranding)],
      child: const SweetTimeApp(),
    ),
  );
}

/// Разбор `?seed=` из URL для демо/скриншотов (auth,cart,history,recurring).
Set<String> _demoSeeds() {
  final raw = Uri.base.queryParameters['seed'];
  if (raw == null || raw.isEmpty) return const {};
  return raw.split(',').map((e) => e.trim()).toSet();
}

class SweetTimeApp extends ConsumerStatefulWidget {
  const SweetTimeApp({super.key});

  @override
  ConsumerState<SweetTimeApp> createState() => _SweetTimeAppState();
}

class _SweetTimeAppState extends ConsumerState<SweetTimeApp>
    with WidgetsBindingObserver {
  static const _scheduledContentRefreshInterval = Duration(seconds: 30);
  Timer? _scheduledContentRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startScheduledContentRefresh();
    // Загружаем production-контент; офлайн сохраняем последний доступный UI.
    unawaited(_bootstrapAndResumeInvite());
    final seeds = _demoSeeds();
    if (seeds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(appStateProvider.notifier)
            .seedDemo(
              auth: seeds.contains('auth'),
              cart: seeds.contains('cart'),
              history: seeds.contains('history'),
              recurring: seeds.contains('recurring'),
            );
      });
    }
  }

  Future<void> _bootstrapAndResumeInvite() async {
    final controller = ref.read(appStateProvider.notifier);
    await controller.bootstrap();
    if (!mounted || ref.read(appStateProvider).isGuest) return;
    final code = await controller.pendingReferralInvite();
    if (!mounted || code == null) return;
    appRouter.go('/invite/$referralCompanyId/${Uri.encodeComponent(code)}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(appStateProvider.notifier);
      unawaited(controller.refreshCompanyData());
      unawaited(controller.resumeCustomerSession());
      _startScheduledContentRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _scheduledContentRefreshTimer?.cancel();
      _scheduledContentRefreshTimer = null;
    }
  }

  void _startScheduledContentRefresh() {
    _scheduledContentRefreshTimer?.cancel();
    _scheduledContentRefreshTimer = Timer.periodic(
      _scheduledContentRefreshInterval,
      (_) => unawaited(
        ref.read(appStateProvider.notifier).refreshPublishedContent(),
      ),
    );
  }

  @override
  void dispose() {
    _scheduledContentRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appStateProvider.select((s) => s.themeMode));
    final appName = ref.watch(appStateProvider.select((s) => s.appName));
    final accent = ref.watch(appStateProvider.select((s) => s.accentColor));
    final language = ref.watch(appStateProvider.select((s) => s.language));
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      locale: language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      // Один фон под всем приложением: Scaffold'ы прозрачны (см. AppTheme), а
      // брендовый фон рисуется здесь, поэтому виден на КАЖДОМ экране, включая
      // push-страницы (товар, оформление, профиль-подэкраны).
      builder: (context, child) =>
          BrandedBackground(child: child ?? const SizedBox.shrink()),
      routerConfig: appRouter,
    );
  }
}
