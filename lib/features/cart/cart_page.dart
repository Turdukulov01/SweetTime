import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/branch_picker.dart';
import '../../shared/widgets/common.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  late final TextEditingController _promoController;
  late final TextEditingController _pointsController;
  bool _promoInvalid = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _promoController = TextEditingController(text: state.promoCode ?? '');
    _pointsController = TextEditingController(
      text: state.bonusApplied > 0 ? '${state.bonusApplied}' : '',
    );
  }

  @override
  void dispose() {
    _promoController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  bool _applyPromo(AppStateController controller) {
    final valid = controller.applyPromoCode(_promoController.text);
    setState(() => _promoInvalid = !valid);
    return valid;
  }

  Future<bool> _validatePromoBeforeCheckout(
    AppStateController controller,
  ) async {
    final valid = await controller.validatePromoCode(_promoController.text);
    if (!mounted) return false;
    setState(() => _promoInvalid = !valid);
    return valid;
  }

  void _applyPoints(AppStateController controller) {
    controller.setBonusPointsToUse(int.tryParse(_pointsController.text) ?? 0);
    final applied = ref.read(appStateProvider).bonusApplied;
    _pointsController.text = applied == 0 ? '' : '$applied';
    _pointsController.selection = TextSelection.collapsed(
      offset: _pointsController.text.length,
    );
  }

  Future<void> _confirmClearCart(
    AppStateController controller,
    AppLocalizations strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.clearCartTitle),
        content: Text(strings.clearCartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.keepCart),
          ),
          FilledButton(
            key: const ValueKey('confirm-clear-cart'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.clearCart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _promoController.clear();
    _pointsController.clear();
    setState(() => _promoInvalid = false);
    await controller.clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final unavailable = state.unavailableForSelectedBranch();
    final compatibleBranchIds = state.branches
        .where(
          (branch) =>
              branch.isOpen &&
              state.cart.every((item) => item.product.availableIn(branch)),
        )
        .map((branch) => branch.id)
        .toSet();

    Future<void> chooseCompatibleBranch() async {
      final branch = await showBranchPicker(
        context,
        branches: state.branches,
        selectedBranch: state.selectedBranch,
        availableBranchIds: compatibleBranchIds,
        title: strings.chooseCompatibleBranch,
      );
      if (!mounted || branch == null) return;
      controller.selectBranch(branch);
    }

    if (state.cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.cart)),
        body: Column(
          children: [
            if (state.cartCatalogAdjusted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _CartCatalogAdjustmentCard(
                  onAcknowledge: controller.acknowledgeCartCatalogAdjustment,
                ),
              ),
            Expanded(
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: strings.emptyCartTitle,
                message: strings.emptyCartMessage,
                action: FilledButton(
                  onPressed: () => context.go('/catalog'),
                  child: Text(strings.goToCatalog),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.cart),
        actions: [
          Tooltip(
            message: strings.clearCartTooltip,
            child: TextButton.icon(
              key: const ValueKey('clear-cart-button'),
              onPressed: () => _confirmClearCart(controller, strings),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(strings.clearCart),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (state.cartCatalogAdjusted) ...[
            _CartCatalogAdjustmentCard(
              onAcknowledge: controller.acknowledgeCartCatalogAdjustment,
            ),
            const SizedBox(height: 12),
          ],
          if (unavailable.isNotEmpty) ...[
            Card(
              key: const ValueKey('cart-branch-availability-warning'),
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.cartUnavailableTitle(unavailable.length),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.cartUnavailableMessage(
                        state.selectedBranch.name.resolve(strings.language),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in unavailable)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              item.product.name.resolve(strings.language),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (compatibleBranchIds.isNotEmpty)
                      FilledButton.tonalIcon(
                        key: const ValueKey('cart-choose-branch-button'),
                        onPressed: chooseCompatibleBranch,
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(strings.chooseCompatibleBranch),
                      )
                    else
                      Text(
                        strings.noCompatibleBranch,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < state.cart.length; i++) ...[
            _CartItemCard(index: i, item: state.cart[i]),
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
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => _applyPromo(controller),
                    onSubmitted: (_) => _applyPromo(controller),
                    decoration: InputDecoration(
                      hintText: strings.promoCode,
                      errorText: _promoInvalid
                          ? strings.invalidPromoCode
                          : null,
                      helperText: state.promoCode == null
                          ? null
                          : strings.promoCodeApplied(state.promoCode!),
                      suffixIcon: IconButton(
                        onPressed: () => _applyPromo(controller),
                        tooltip: strings.applyPromoCode,
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.useBonus,
                    onChanged: state.maxBonusSpend > 0
                        ? (value) {
                            controller.setUseBonus(value);
                            final next = ref
                                .read(appStateProvider)
                                .bonusApplied;
                            _pointsController.text = next == 0 ? '' : '$next';
                          }
                        : null,
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
                  if (state.maxBonusSpend > 0) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pointsController,
                      enabled: state.useBonus,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _applyPoints(controller),
                      onEditingComplete: () => _applyPoints(controller),
                      decoration: InputDecoration(
                        labelText: strings.pointsAmount,
                        helperText: strings.pointsAmountLimit(
                          state.maxBonusSpend,
                        ),
                        suffixIcon: IconButton(
                          onPressed: state.useBonus
                              ? () => _applyPoints(controller)
                              : null,
                          icon: const Icon(Icons.check),
                        ),
                      ),
                    ),
                  ],
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
            key: const ValueKey('cart-checkout-button'),
            onPressed: unavailable.isNotEmpty
                ? null
                : () async {
                    // A non-empty promo is checked against the latest active
                    // promotions before navigation. Empty input remains optional.
                    if (!await _validatePromoBeforeCheckout(controller)) return;
                    if (!context.mounted) return;
                    final currentState = ref.read(appStateProvider);
                    if (!currentState.accountReady) {
                      controller.requestAuthentication(
                        AuthReturnDestination.checkout,
                      );
                      context.push(AuthReturnDestination.checkout.authLocation);
                      return;
                    }
                    context.push(AuthReturnDestination.checkout.location);
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

class _CartCatalogAdjustmentCard extends StatelessWidget {
  const _CartCatalogAdjustmentCard({required this.onAcknowledge});

  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('cart-catalog-adjustment-warning'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_problem_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.cartCatalogAdjustedTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.cartCatalogAdjustedMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('acknowledge-cart-adjustment'),
                onPressed: onAcknowledge,
                child: Text(strings.understood),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.index, required this.item});

  final int index;
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                TextButton.icon(
                  key: ValueKey('edit-cart-item-$index'),
                  onPressed: () => context.push('/cart/edit/$index'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(strings.editCartItem),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
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
