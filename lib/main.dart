import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'shared/app_state.dart';
import 'shared/app_models.dart';

void main() {
  runApp(const ProviderScope(child: SweetTimeApp()));
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Загружаем production-контент; офлайн сохраняем последний доступный UI.
    ref.read(appStateProvider.notifier).bootstrap();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appStateProvider.notifier).refreshCompanyData();
    }
  }

  @override
  void dispose() {
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
      routerConfig: appRouter,
    );
  }
}
