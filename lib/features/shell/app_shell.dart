import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/app_state.dart';
import '../../core/localization/app_localizations.dart';

/// Оболочка приложения с нижней таб-навигацией (эталон — mobile-tab-bar прототипа).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(appStateProvider.select((s) => s.cartCount));
    final strings = AppLocalizations.of(context);

    return PopScope<void>(
      // На корневых вкладках Back сначала возвращает на Главную. Только Back
      // с самой Главной может закрыть приложение — стандартное Android UX.
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          animationDuration: const Duration(milliseconds: 200),
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_rounded),
              selectedIcon: const Icon(Icons.home_rounded),
              label: strings.home,
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_cafe_rounded),
              selectedIcon: const Icon(Icons.local_cafe_rounded),
              label: strings.catalog,
            ),
            NavigationDestination(
              icon: const Icon(Icons.qr_code_2),
              selectedIcon: const Icon(Icons.qr_code_2),
              label: strings.qr,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_bag_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_bag_rounded),
              ),
              label: strings.cart,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: strings.profile,
            ),
          ],
        ),
      ),
    );
  }
}
