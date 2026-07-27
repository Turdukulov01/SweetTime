import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_page.dart';
import '../features/cart/cart_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/checkout/checkout_page.dart';
import '../features/home/home_page.dart';
import '../features/news/news_story_page.dart';
import '../features/news/news_page.dart';
import '../features/product/product_page.dart';
import '../features/profile/faq_page.dart';
import '../features/profile/loyalty_page.dart';
import '../features/profile/order_history_page.dart';
import '../features/profile/profile_edit_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/recurring_orders_page.dart';
import '../features/profile/support_page.dart';
import '../features/qr/qr_page.dart';
import '../features/qr/referral_invite_page.dart';
import '../features/shell/app_shell.dart';
import '../shared/app_state.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'product/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) =>
                      ProductPage(productId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/qr', builder: (context, state) => const QrPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cart',
              builder: (context, state) => const CartPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/invite/:companyId/:code',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => ReferralInvitePage(
        companyId: state.pathParameters['companyId'] ?? '',
        rawCode: state.pathParameters['code'] ?? '',
      ),
    ),
    GoRoute(
      path: '/news',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const NewsPage(),
    ),
    GoRoute(
      path: '/news/story/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          NewsStoryPage(initialStoryId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/news/collection/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          NewsStoryPage(collectionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/news/:id',
      redirect: (context, state) => '/news/story/${state.pathParameters['id']}',
    ),
    GoRoute(
      path: '/checkout',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const _ProtectedCheckoutRoute(),
    ),
    GoRoute(
      path: '/cart/edit/:index',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => _CartItemEditRoute(
        index: int.tryParse(state.pathParameters['index'] ?? '') ?? -1,
      ),
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: '/profile/edit',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          const _ProtectedProfileRoute(child: EditProfilePage()),
    ),
    GoRoute(
      path: '/profile/loyalty',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          const _ProtectedProfileRoute(child: LoyaltyPage()),
    ),
    GoRoute(
      path: '/profile/orders',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          const _ProtectedProfileRoute(child: OrderHistoryPage()),
    ),
    GoRoute(
      path: '/profile/recurring',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          const _ProtectedProfileRoute(child: RecurringOrdersPage()),
    ),
    GoRoute(
      path: '/profile/support',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const SupportPage(),
    ),
    GoRoute(
      path: '/profile/faq',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const FaqPage(),
    ),
  ],
);

class _CartItemEditRoute extends ConsumerWidget {
  const _CartItemEditRoute({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(appStateProvider.select((state) => state.cart));
    if (index < 0 || index >= cart.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/cart');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProductPage(productId: cart[index].product.id, editCartIndex: index);
  }
}

class _ProtectedCheckoutRoute extends ConsumerWidget {
  const _ProtectedCheckoutRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountReady = ref.watch(
      appStateProvider.select((state) => state.accountReady),
    );
    return !accountReady
        ? const _AuthenticationRedirect(
            destination: AuthReturnDestination.checkout,
          )
        : const CheckoutPage();
  }
}

class _AuthenticationRedirect extends ConsumerStatefulWidget {
  const _AuthenticationRedirect({required this.destination});

  final AuthReturnDestination destination;

  @override
  ConsumerState<_AuthenticationRedirect> createState() =>
      _AuthenticationRedirectState();
}

class _AuthenticationRedirectState
    extends ConsumerState<_AuthenticationRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(appStateProvider.notifier)
          .requestAuthentication(widget.destination);
      context.go(widget.destination.authLocation);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ProtectedProfileRoute extends ConsumerWidget {
  const _ProtectedProfileRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(
      appStateProvider.select((state) => state.isGuest),
    );
    return isGuest ? const ProfilePage() : child;
  }
}
