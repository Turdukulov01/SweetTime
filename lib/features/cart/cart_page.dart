import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);

    if (state.cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.cart)),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: strings.emptyCartTitle,
          message: strings.emptyCartMessage,
          action: FilledButton(
            onPressed: () => context.go('/catalog'),
            child: Text(strings.goToCatalog),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.cart)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          for (var i = 0; i < state.cart.length; i++) ...[
            _CartItemCard(index: i),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.orderSummary, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(hintText: strings.promoCode),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.useBonus,
                    onChanged: controller.setUseBonus,
                    title: Text(strings.usePoints),
                    subtitle: Text(
                      strings.pointsSpendSummary(
                        formatPoints(state.points, strings.language),
                        formatPoints(state.maxBonusSpend, strings.language),
                        (state.loyaltyMaxSpendShare * 100).round(),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Divider(height: 24),
                  _Row(
                    label: strings.orderSubtotal,
                    value: formatSom(state.subtotal, strings.language),
                  ),
                  if (state.bonusApplied > 0) ...[
                    const SizedBox(height: 8),
                    _Row(
                      label: strings.paidWithPoints,
                      value: formatSom(-state.bonusApplied, strings.language),
                      valueColor: theme.colorScheme.secondary,
                    ),
                  ],
                  const Divider(height: 24),
                  _Row(
                    label: strings.amountDue,
                    value: formatSom(state.total, strings.language),
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.pointsEarnPreview(
                          state.pointsEarned,
                          (state.loyaltyEarnRate * 100).round(),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () {
              if (!state.accountReady) {
                controller.requestAuthentication(
                  AuthReturnDestination.checkout,
                );
                context.go(AuthReturnDestination.checkout.authLocation);
                return;
              }
              context.go(AuthReturnDestination.checkout.location);
            },
            child: Text(
              strings.checkoutWithTotal(
                formatSom(state.total, strings.language),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(appStateProvider.select((s) => s.cart[index]));
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final productName = strings.productName(item.product);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(productName, style: theme.textTheme.titleMedium),
                ),
                Text(
                  formatSom(item.total, strings.language),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.cartModifiers(item),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                QuantityStepper(
                  quantity: item.quantity,
                  onDecrement: () => controller.updateQuantity(index, -1),
                  onIncrement: () => controller.updateQuantity(index, 1),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => controller.removeFromCart(index),
                  tooltip: strings.removeCartItem(productName),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style?.copyWith(color: valueColor)),
      ],
    );
  }
}
