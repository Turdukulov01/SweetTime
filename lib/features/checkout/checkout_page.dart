import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  OrderType _type = OrderType.pickup;
  PaymentMethod _payment = PaymentMethod.mock;
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);
  final _tableController = TextEditingController();
  final _commentController = TextEditingController();
  late final String _clientRequestId = _newClientRequestId();
  bool _submitting = false;

  static String _newClientRequestId() {
    final random = Random.secure();
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final entropy = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return 'mobile-$time-$entropy';
  }

  @override
  void dispose() {
    _tableController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final unavailable = state.unavailableForSelectedBranch();
    final needsTable = _type == OrderType.qrCafe;
    final canPlace =
        !_submitting &&
        state.cart.isNotEmpty &&
        unavailable.isEmpty &&
        (!needsTable || _tableController.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(strings.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _CardSection(
            icon: Icons.storefront_outlined,
            title: strings.branch,
            child: Column(
              children: [
                for (final branch in state.branches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableTile(
                      selected: branch.id == state.selectedBranch.id,
                      onTap: () => ref
                          .read(appStateProvider.notifier)
                          .selectBranch(branch),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.branchName(branch),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${strings.branchAddress(branch)} · ${branch.hours}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (unavailable.isNotEmpty)
                  _UnavailableWarning(items: unavailable),
              ],
            ),
          ),
          _CardSection(
            icon: Icons.schedule_outlined,
            title: strings.fulfillmentMethod,
            child: Column(
              children: [
                for (final type in OrderType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableTile(
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                      child: Row(
                        children: [
                          Icon(type.icon, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.orderTypeLabel(type),
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  strings.orderTypeHint(type),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_type == OrderType.scheduled) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text(strings.prepareBy),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      child: Text(_time.format(context)),
                    ),
                  ),
                ],
                if (_type == OrderType.qrCafe) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tableController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: strings.tableNumber,
                      hintText: strings.tableNumberExample,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.tableQrAutofillDemo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _CardSection(
            icon: Icons.credit_card_outlined,
            title: strings.payment,
            child: Column(
              children: [
                for (final method in PaymentMethod.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableTile(
                      selected: _payment == method,
                      onTap: () => setState(() => _payment = method),
                      child: Row(
                        children: [
                          Icon(method.icon, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.paymentMethodLabel(method),
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  strings.paymentMethodHint(method),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_payment == PaymentMethod.qrDemo)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 96,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.paymentQrDemoNotice,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _CardSection(
            icon: Icons.chat_bubble_outline,
            title: strings.comment,
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(hintText: strings.baristaCommentHint),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strings.amountDue, style: theme.textTheme.titleMedium),
                  Text(
                    formatSom(state.total, strings.language),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: canPlace ? () => _placeOrder(state) : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.payAndPlaceOrder),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(AppState state) async {
    final controller = ref.read(appStateProvider.notifier);
    if (!state.accountReady) {
      _requestAuthentication(controller);
      return;
    }
    if (!state.catalogAuthoritative) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).orderCatalogUnavailable),
        ),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final strings = AppLocalizations.of(context);
    final readyTime = switch (_type) {
      OrderType.scheduled => OrderReadyTime(
        kind: OrderReadyTimeKind.scheduled,
        value:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      ),
      OrderType.qrCafe => OrderReadyTime(
        kind: OrderReadyTimeKind.table,
        value: _tableController.text.trim(),
      ),
      OrderType.pickup => const OrderReadyTime(kind: OrderReadyTimeKind.asap),
    };
    final apiReadyTime = strings.readyTimeLabel(readyTime);
    // Первый выполненный заказ приглашённого → пригласившему уходит бонус (REFERRAL_LOGIC.md).
    final inviterRewarded = state.orders.isEmpty && state.invitedByCode != null;

    // Снимок данных для API до локального оформления (checkout очищает корзину).
    final cartItems = state.cart;
    final branch = state.selectedBranch;
    final pointsUsed = state.bonusApplied;
    final total = state.total;

    // Только подтверждённый сервером заказ считается принятым. При ошибке
    // корзина остаётся на устройстве, а тот же request id безопасно повторяется.
    final result = await controller.submitOrder(
      clientRequestId: _clientRequestId,
      type: _type,
      readyTime: apiReadyTime,
      items: cartItems,
      branch: branch,
      pointsUsed: pointsUsed,
      paymentMethod: _payment,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.isOk) {
      if (result.isRejected) {
        controller.logout();
        _requestAuthentication(controller);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.orderSubmissionUnavailable)),
      );
      return;
    }
    final created = result.value!;
    final order = CustomerOrder(
      id: created.number,
      items: cartItems,
      branch: branch,
      type: _type,
      status: OrderStatus.created,
      paymentMethod: _payment,
      readyTime: readyTime,
      total: total,
      pointsUsed: pointsUsed,
      pointsEarned: created.pointsEarned,
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(
        order: order,
        serverNumber: created.number,
        serverPointsEarned: created.pointsEarned,
        inviterRewarded: inviterRewarded,
      ),
    );
  }

  void _requestAuthentication(AppStateController controller) {
    controller.requestAuthentication(AuthReturnDestination.checkout);
    context.go(AuthReturnDestination.checkout.authLocation);
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _UnavailableWarning extends StatelessWidget {
  const _UnavailableWarning({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final names = items
        .map((item) => '«${strings.productName(item.product)}»')
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.cartItemsUnavailableAtBranch(names),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.order,
    this.serverNumber,
    this.serverPointsEarned,
    this.inviterRewarded = false,
  });

  final CustomerOrder order;

  /// Номер и баллы из ответа сервера (POST /orders); null — офлайн-заказ.
  final String? serverNumber;
  final int? serverPointsEarned;
  final bool inviterRewarded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final number = serverNumber ?? order.id;
    final pointsEarned = serverPointsEarned ?? order.pointsEarned;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 56,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              strings.orderAccepted(number),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              strings.orderStatusAt(
                status: strings.orderStatusLabel(order.status),
                branch: strings.branchName(order.branch),
                readyTime: strings.readyTimeLabel(order.readyTime),
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.pointsEarned(pointsEarned),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (inviterRewarded) ...[
              const SizedBox(height: 6),
              Text(
                strings.friendReferralRewarded(Referral.inviterBonus),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/profile');
                },
                child: Text(strings.trackOrder),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/');
              },
              child: Text(strings.goHome),
            ),
          ],
        ),
      ),
    );
  }
}
