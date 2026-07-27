import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import 'recurring_sheet.dart';

/// Отдельный экран постоянных заказов: у клиента их может быть много, поэтому
/// список вынесен из Профиля, как и «Баллы». Контент карточки подписок
/// переиспользуется без изменений.
class RecurringOrdersPage extends ConsumerWidget {
  const RecurringOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (
          recurringOrders: state.recurringOrders,
          recurringRefunds: state.recurringRefunds,
          products: state.products,
          branches: state.branches,
        ),
      ),
    );
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.recurringOrdersPageTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            RecurringCard(
              recurringOrders: state.recurringOrders,
              recurringRefunds: state.recurringRefunds,
              products: state.products,
              branches: state.branches,
            ),
          ],
        ),
      ),
    );
  }
}

class RecurringCard extends ConsumerWidget {
  const RecurringCard({
    super.key,
    required this.recurringOrders,
    required this.recurringRefunds,
    required this.products,
    required this.branches,
  });

  final List<RecurringOrder> recurringOrders;
  final List<RecurringRefund> recurringRefunds;
  final List<Product> products;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_repeat_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.recurringOrderTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: strings.retry,
                  onPressed: () => ref
                      .read(appStateProvider.notifier)
                      .refreshCustomerRecurring(),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recurringOrders.isEmpty) ...[
              Text(
                strings.recurringIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => showRecurringSheet(context, ref),
                icon: const Icon(Icons.add),
                label: Text(strings.recurringConfigure),
              ),
            ] else ...[
              Text(
                strings.recurringMultipleIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < recurringOrders.length; index++) ...[
                _RecurringActive(
                  recurring: recurringOrders[index],
                  products: products,
                  branches: branches,
                ),
                if (index != recurringOrders.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: recurringOrders.length >= 20
                    ? null
                    : () => showRecurringSheet(context, ref),
                icon: const Icon(Icons.add),
                label: Text(strings.recurringAddAnother),
              ),
            ],
            if (recurringRefunds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                strings.recurringRefundHistory,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final refund in recurringRefunds.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    refund.requiresManualPayment
                        ? Icons.qr_code_2
                        : Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    strings.recurringRefundAmount(
                      formatSom(refund.amount, strings.language),
                    ),
                  ),
                  subtitle: Text(strings.recurringRefundStatus(refund.status)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showRecurringRefundReceipt(context, refund, strings),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecurringActive extends ConsumerWidget {
  const _RecurringActive({
    required this.recurring,
    required this.products,
    required this.branches,
  });

  final RecurringOrder recurring;
  final List<Product> products;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final branch = branches
        .where((candidate) => candidate.id == recurring.branchId)
        .firstOrNull;
    final branchName = branch == null
        ? strings.profileUnknownBranch(recurring.branchId)
        : strings.branchName(branch);
    final lockedItemsByProductId = <String, RecurringOrderItem>{
      for (final item in recurring.items) item.productId: item,
    };
    final productNames = recurring.productIds
        .map((productId) {
          final product = products
              .where((candidate) => candidate.id == productId)
              .firstOrNull;
          return product == null
              ? (lockedItemsByProductId[productId]?.name.resolve(
                      strings.language,
                    ) ??
                    strings.recurringProductUnavailable(productId))
              : strings.productName(product);
        })
        .join(' + ');
    final paidUntilLabel = recurring.paidUntil == null
        ? strings.recurringPaidUntilUnavailable
        : strings.recurringPaidUntil(recurring.paidUntil!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.recurringActiveLabel(recurring.plan),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$productNames\n'
            '${strings.recurringSchedule(recurring.time, branchName)}\n'
            '$paidUntilLabel\n'
            '${strings.recurringDailyPrice(formatSom(recurring.dailyTotal, strings.language))}\n'
            '${strings.recurringPrepaidTotal(formatSom(recurring.prepaidTotal, strings.language))}',
            style: theme.textTheme.bodyMedium,
          ),
          if (recurring.lastAdjustment != 0) ...[
            const SizedBox(height: 6),
            Text(
              recurring.lastAdjustment > 0
                  ? strings.recurringDemoTopUp(
                      formatSom(recurring.lastAdjustment, strings.language),
                    )
                  : strings.recurringMoneyCredit(
                      formatSom(-recurring.lastAdjustment, strings.language),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: ValueKey('recurring-edit-${recurring.id}'),
                onPressed: () =>
                    showRecurringSheet(context, ref, existing: recurring),
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.recurringEdit),
              ),
              TextButton(
                onPressed: () async {
                  final controller = ref.read(appStateProvider.notifier);
                  final quote = await controller.recurringCancellationQuote(
                    recurringId: recurring.id,
                  );
                  if (!context.mounted) return;
                  if (quote == null) {
                    _showRepeatMessage(
                      context,
                      strings.recurringCancellationQuoteFailed,
                    );
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(strings.recurringCancelTitle),
                      content: Text(
                        strings.recurringCancellationQuoteBody(
                          formatSom(quote.refundAmount, strings.language),
                          quote.refundableOccurrences,
                          quote.nonRefundableOrderIds.length,
                          quote.cutoffMinutes,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(strings.recurringKeep),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(strings.recurringConfirmCancel),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  final cancellation = await controller
                      .cancelRecurringWithResult(recurringId: recurring.id);
                  if (!context.mounted) return;
                  if (cancellation == null) {
                    _showRepeatMessage(context, strings.recurringCancelFailed);
                    return;
                  }
                  await _showRecurringRefundReceipt(
                    context,
                    cancellation.refund,
                    strings,
                  );
                },
                child: Text(strings.recurringCancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showRecurringRefundReceipt(
  BuildContext context,
  RecurringRefund refund,
  AppLocalizations strings,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    refund.requiresManualPayment
                        ? Icons.qr_code_2
                        : Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.recurringRefundReceiptTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RefundDetailRow(
                label: strings.recurringRefundStatusLabel,
                value: strings.recurringRefundStatus(refund.status),
              ),
              _RefundDetailRow(
                label: strings.recurringRefundAmountLabel,
                value: formatSom(refund.amount, strings.language),
              ),
              _RefundDetailRow(
                label: strings.recurringRefundMethodLabel,
                value: strings.paymentMethodLabel(refund.paymentMethod),
              ),
              _RefundDetailRow(
                label: strings.recurringRefundReferenceLabel,
                value: refund.providerRefundId ?? refund.id,
              ),
              if (refund.requiresManualPayment &&
                  refund.claimQrPayload != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: refund.claimQrPayload!,
                        size: 208,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (refund.claimCode != null)
                  Center(
                    child: SelectableText(
                      refund.claimCode!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  strings.recurringManualRefundInstruction,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  strings.recurringAutomaticRefundInstruction(refund.status),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (refund.failureMessage?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text(
                  strings.recurringRefundProviderNote(refund.failureMessage!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(strings.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RefundDetailRow extends StatelessWidget {
  const _RefundDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showRepeatMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
