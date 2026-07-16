import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/top_notice.dart';

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 10);

  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _refreshFailed = false;
  Timer? _pollTimer;
  Future<CustomerHistoryRefreshResult>? _refreshInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling();
        unawaited(_refreshHistory(showErrors: false));
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _pollTimer?.cancel();
        _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_refreshHistory(showErrors: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (
          orders: state.visibleOrders,
          products: state.products,
          branches: state.branches,
          language: state.language,
        ),
      ),
    );
    final strings = AppLocalizations.of(context);
    final visibleIds = state.orders.map((order) => order.id).toSet();
    _selectedIds.removeWhere((id) => !visibleIds.contains(id));

    return PopScope<void>(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionMode
              ? IconButton(
                  tooltip: strings.orderHistoryExitSelection,
                  onPressed: _exitSelectionMode,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          title: Text(
            _selectionMode
                ? strings.orderHistorySelected(_selectedIds.length)
                : strings.profileOrderHistory,
          ),
          actions: _selectionMode
              ? [
                  IconButton(
                    tooltip: _selectedIds.length == state.orders.length
                        ? strings.orderHistoryClearSelection
                        : strings.orderHistorySelectAll,
                    onPressed: state.orders.isEmpty
                        ? null
                        : () => _toggleSelectAll(state.orders),
                    icon: Icon(
                      _selectedIds.length == state.orders.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filledTonal(
                      key: const ValueKey('hide-selected-orders'),
                      tooltip: strings.orderHistoryHideSelected,
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _confirmHideOrders(context),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filledTonal(
                      key: const ValueKey('manage-order-history'),
                      tooltip: strings.orderHistoryManage,
                      onPressed: state.orders.isEmpty
                          ? null
                          : () => setState(() => _selectionMode = true),
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                  ),
                ],
        ),
        body: RefreshIndicator(
          key: const ValueKey('order-history-refresh'),
          semanticsLabel: strings.orderHistoryRefresh,
          onRefresh: _refreshHistory,
          child: CustomScrollView(
            key: const PageStorageKey('order-history-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_refreshFailed)
                SliverToBoxAdapter(
                  child: _RefreshErrorCard(onRetry: _refreshHistory),
                ),
              if (state.orders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: strings.profileOrderHistoryEmptyCompact,
                    message: strings.profileOrderHistoryEmpty,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: state.orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = state.orders[index];
                      return _OrderListCard(
                        key: ValueKey('order-${order.id}'),
                        order: order,
                        branch: state.branches
                            .where((branch) => branch.id == order.branchId)
                            .firstOrNull,
                        selected: _selectedIds.contains(order.id),
                        selectionMode: _selectionMode,
                        onTap: () {
                          if (_selectionMode) {
                            _toggleOrder(order.id);
                          } else {
                            _showOrderDetail(
                              context,
                              order: order,
                              products: state.products,
                              branches: state.branches,
                            );
                          }
                        },
                        onLongPress: () {
                          if (!_selectionMode) {
                            setState(() {
                              _selectionMode = true;
                              _selectedIds.add(order.id);
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOrder(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  void _toggleSelectAll(List<OrderHistoryEntry> orders) {
    setState(() {
      if (_selectedIds.length == orders.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(orders.map((order) => order.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _refreshHistory({bool showErrors = true}) async {
    final active = _refreshInFlight;
    late final Future<CustomerHistoryRefreshResult> request;
    if (active != null) {
      request = active;
    } else {
      request = ref.read(appStateProvider.notifier).refreshCustomerOrders();
      _refreshInFlight = request;
    }
    final result = await request;
    if (identical(_refreshInFlight, request)) _refreshInFlight = null;
    if (!mounted) return;
    switch (result) {
      case CustomerHistoryRefreshResult.success:
        setState(() => _refreshFailed = false);
      case CustomerHistoryRefreshResult.unavailable:
        if (showErrors) setState(() => _refreshFailed = true);
      case CustomerHistoryRefreshResult.sessionExpired:
        setState(() => _refreshFailed = false);
        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).orderHistorySessionExpired,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    }
  }

  Future<void> _confirmHideOrders(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.orderHistoryHideTitle),
        content: Text(strings.orderHistoryHideBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.orderHistoryHideCancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(strings.orderHistoryHideConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final selected = Set<String>.from(_selectedIds);
    await ref.read(appStateProvider.notifier).hideOrdersOnDevice(selected);
    if (!context.mounted) return;
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.orderHistoryHidden(count)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _RefreshErrorCard extends StatelessWidget {
  const _RefreshErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        key: const ValueKey('order-history-refresh-error'),
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.orderHistoryRefreshFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(strings.orderHistoryRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({
    super.key,
    required this.order,
    required this.branch,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final OrderHistoryEntry order;
  final Branch? branch;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final date = order.createdAt;
    final subtitle = [
      if (date != null) _formatOrderDate(context, date),
      strings.profileOrderItemsCount(order.items.length),
      _orderBranchName(strings, order, branch),
    ].join(' · ');
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selectionMode
                    ? Checkbox(
                        key: ValueKey('selected-${order.id}-$selected'),
                        value: selected,
                        onChanged: (_) => onTap(),
                      )
                    : Container(
                        key: ValueKey('icon-${order.id}'),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(order.type.icon),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.number,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        _OrderStatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatSom(order.total, strings.language),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active =
        status == OrderStatus.preparing || status == OrderStatus.ready;
    final color = active
        ? theme.colorScheme.primary
        : status == OrderStatus.cancelled
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocalizations.of(context).orderStatusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _showOrderDetail(
  BuildContext context, {
  required OrderHistoryEntry order,
  required List<Product> products,
  required List<Branch> branches,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _OrderDetailSheet(
        order: order,
        products: products,
        branches: branches,
      ),
    ),
  );
}

class _OrderDetailSheet extends ConsumerWidget {
  const _OrderDetailSheet({
    required this.order,
    required this.products,
    required this.branches,
  });

  final OrderHistoryEntry order;
  final List<Product> products;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final branch = branches
        .where((candidate) => candidate.id == order.branchId)
        .firstOrNull;
    final comment = order.comment?.trim();
    final customerPhone = order.customerPhone?.trim();
    return CustomScrollView(
      key: const ValueKey('order-detail-sheet'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.orderDetailsTitle,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        order.number,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _OrderStatusPill(status: order.status),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _OrderInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: strings.orderDetailsDate,
                          value: order.createdAt == null
                              ? strings.orderDetailsDateUnavailable
                              : _formatOrderDate(context, order.createdAt!),
                        ),
                        _OrderInfoRow(
                          icon: Icons.storefront_outlined,
                          label: strings.orderDetailsBranch,
                          value: _orderBranchDetails(strings, order, branch),
                        ),
                        _OrderInfoRow(
                          icon: order.type.icon,
                          label: strings.orderDetailsType,
                          value: strings.orderTypeLabel(order.type),
                        ),
                        _OrderInfoRow(
                          icon: Icons.schedule_outlined,
                          label: strings.orderDetailsReadyTime,
                          value: strings.readyTimeLabel(order.readyTime),
                        ),
                        _OrderInfoRow(
                          icon: order.paymentMethod.icon,
                          label: strings.orderDetailsPayment,
                          value: strings.paymentMethodLabel(
                            order.paymentMethod,
                          ),
                        ),
                        _OrderInfoRow(
                          icon: Icons.monitor_heart_outlined,
                          label: strings.orderDetailsStatus,
                          value: strings.orderStatusLabel(order.status),
                          isLast:
                              customerPhone == null || customerPhone.isEmpty,
                        ),
                        if (customerPhone != null && customerPhone.isNotEmpty)
                          _OrderInfoRow(
                            icon: Icons.phone_outlined,
                            label: strings.orderDetailsCustomerPhone,
                            value: customerPhone,
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  strings.orderDetailsItems,
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: order.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _OrderItemDetail(
              item: order.items[index],
              product: order.items[index].productId == null
                  ? null
                  : products
                        .where(
                          (product) =>
                              product.id == order.items[index].productId,
                        )
                        .firstOrNull,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (comment != null && comment.isNotEmpty) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline_rounded),
                      title: Text(strings.orderDetailsComment),
                      subtitle: Text(comment),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (order.promoCode case final promoCode?) ...[
                          _PriceRow(
                            label: strings.orderDetailsPromoCode,
                            value: promoCode,
                          ),
                          const SizedBox(height: 8),
                        ],
                        _PriceRow(
                          label: strings.orderDetailsPointsUsed,
                          value: strings.pointCount(order.pointsUsed),
                        ),
                        const SizedBox(height: 8),
                        _PriceRow(
                          label: strings.orderDetailsPointsEarned,
                          value: strings.pointCount(order.pointsEarned),
                        ),
                        const Divider(height: 24),
                        _PriceRow(
                          label: strings.orderDetailsTotal,
                          value: formatSom(order.total, strings.language),
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.supportsExactRepeat) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _repeatOrder(context, ref, order),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(strings.profileRepeatOrder),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.profileLegacyOrderRepeatUnavailable,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemDetail extends StatelessWidget {
  const _OrderItemDetail({required this.item, required this.product});

  final OrderHistoryItem item;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final currentProduct = product;
    final productName = currentProduct == null
        ? item.productName.resolve(strings.language)
        : strings.productName(currentProduct);
    final description =
        currentProduct?.description.resolve(strings.language) ??
        item.productDescription?.resolve(strings.language);
    final modifiers = _itemModifiers(strings, item, currentProduct);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductThumb(item: item, product: currentProduct),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productName, style: theme.textTheme.titleMedium),
                  if (description != null && description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (modifiers.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      modifiers,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        strings.orderDetailsQuantity(item.quantity),
                        style: theme.textTheme.labelMedium,
                      ),
                      if (item.unitPrice case final unitPrice?)
                        Text(
                          strings.orderDetailsUnitPrice(
                            formatSom(unitPrice, strings.language),
                          ),
                          style: theme.textTheme.labelMedium,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatSom(item.total, strings.language),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (currentProduct == null) ...[
                    const SizedBox(height: 7),
                    Text(
                      strings.orderDetailsSnapshotProduct,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.item, required this.product});

  final OrderHistoryItem item;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = product;
    final assetImage = current?.assetImage;
    final imageUrl = (item.imageUrl ?? current?.imageUrl)?.trim();
    final fallback = _ProductThumbFallback(
      color: current?.accentColor ?? theme.colorScheme.surfaceContainerHighest,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 82,
        height: 96,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 246,
                errorBuilder: (context, error, stackTrace) => assetImage != null
                    ? Image.asset(
                        assetImage,
                        fit: BoxFit.cover,
                        cacheWidth: 246,
                        errorBuilder: (context, error, stackTrace) => fallback,
                      )
                    : fallback,
              )
            : assetImage != null
            ? Image.asset(
                assetImage,
                fit: BoxFit.cover,
                cacheWidth: 246,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _ProductThumbFallback extends StatelessWidget {
  const _ProductThumbFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Icon(
        Icons.local_cafe_outlined,
        color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black54,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

String _itemModifiers(
  AppLocalizations strings,
  OrderHistoryItem item,
  Product? product,
) {
  final values = <String>[];
  final size = item.sizeId == null
      ? null
      : product?.sizes.where((option) => option.id == item.sizeId).firstOrNull;
  final sizeName =
      item.sizeName?.resolve(strings.language) ??
      size?.name.resolve(strings.language);
  if (sizeName != null && sizeName.trim().isNotEmpty) values.add(sizeName);
  if (item.sugarPercent case final sugar?) {
    values.add('${strings.sugarLabel}: $sugar%');
  }
  if (item.ice case final ice?) values.add(strings.iceLevelLabel(ice));
  for (final toppingId in item.toppingIds ?? const <String>[]) {
    final toppingSnapshot = item.toppings
        ?.where((option) => option.id == toppingId)
        .firstOrNull;
    final currentTopping = product?.toppings
        .where((option) => option.id == toppingId)
        .firstOrNull;
    final topping = toppingSnapshot ?? currentTopping;
    if (topping == null) {
      values.add(strings.orderDetailsUnknownTopping(toppingId));
      continue;
    }
    final name = topping.name.resolve(strings.language);
    values.add(
      topping.priceDelta == 0
          ? name
          : '$name (+${formatSom(topping.priceDelta, strings.language)})',
    );
  }
  return values.join(' · ');
}

String _orderBranchName(
  AppLocalizations strings,
  OrderHistoryEntry order,
  Branch? currentBranch,
) {
  final snapshotName = order.branchName?.trim();
  if (snapshotName != null && snapshotName.isNotEmpty) return snapshotName;
  return currentBranch == null
      ? strings.profileUnknownBranch(order.branchId)
      : strings.branchName(currentBranch);
}

String _orderBranchDetails(
  AppLocalizations strings,
  OrderHistoryEntry order,
  Branch? currentBranch,
) {
  final name = _orderBranchName(strings, order, currentBranch);
  final snapshotAddress = order.branchAddress?.trim();
  final address = snapshotAddress != null && snapshotAddress.isNotEmpty
      ? snapshotAddress
      : currentBranch?.address.resolve(strings.language);
  return address == null || address.trim().isEmpty ? name : '$name\n$address';
}

String _formatOrderDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)}, '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

Future<void> _repeatOrder(
  BuildContext context,
  WidgetRef ref,
  OrderHistoryEntry order,
) async {
  final strings = AppLocalizations.of(context);
  final result = await ref.read(appStateProvider.notifier).repeatOrder(order);
  if (!context.mounted) return;
  switch (result) {
    case RepeatOrderResult.success:
      Navigator.of(context).pop();
      showTopNotice(
        context,
        message: strings.orderAddedToCart,
        actionLabel: strings.cart,
        onAction: () => context.go('/cart'),
      );
      context.go('/cart');
    case RepeatOrderResult.legacyOrder:
      _showOrderMessage(context, strings.profileLegacyOrderRepeatUnavailable);
    case RepeatOrderResult.catalogUnavailable:
      _showOrderMessage(context, strings.profileRepeatNeedsServerCatalog);
    case RepeatOrderResult.unavailableSelection:
      _showOrderMessage(context, strings.profileRepeatSelectionUnavailable);
  }
}

void _showOrderMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
