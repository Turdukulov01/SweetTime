import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/top_notice.dart';
import 'recurring_sheet.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      appStateProvider.select(
        (state) => (isGuest: state.isGuest, language: state.language),
      ),
    );
    final controller = ref.read(appStateProvider.notifier);
    final strings = AppLocalizations.of(context);

    if (profile.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.profile),
          actions: [
            _LanguageMenuButton(
              language: profile.language,
              onSelected: controller.setLanguage,
            ),
            _ThemeButton(onPressed: controller.toggleTheme),
          ],
        ),
        body: EmptyState(
          icon: Icons.person_outline,
          title: strings.guestProfileTitle,
          message: strings.profileGuestMessage,
          action: FilledButton(
            onPressed: () => context.push('/auth'),
            child: Text(strings.login),
          ),
        ),
      );
    }

    return const _ProfileContent();
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      appStateProvider.select(
        (state) => (
          language: state.language,
          firstName: state.firstName,
          lastName: state.lastName,
          avatarUrl: state.avatarUrl,
          userContact: state.userContact,
          points: state.points,
          recurring: state.recurring,
          orders: state.orders,
          products: state.products,
          branches: state.branches,
        ),
      ),
    );
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.profile,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                _LanguageMenuButton(
                  language: profile.language,
                  onSelected: controller.setLanguage,
                ),
                _ThemeButton(onPressed: controller.toggleTheme),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileHeaderCard(
              firstName: profile.firstName,
              lastName: profile.lastName,
              avatarUrl: profile.avatarUrl,
              userContact: profile.userContact,
            ),
            const SizedBox(height: 12),
            _PointsEntry(points: profile.points),
            const SizedBox(height: 12),
            _RecurringCard(
              recurring: profile.recurring,
              products: profile.products,
              branches: profile.branches,
            ),
            const SizedBox(height: 24),
            Text(
              strings.profileOrderHistory,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (profile.orders.isEmpty)
              _MutedCard(text: strings.profileOrderHistoryEmpty)
            else
              for (final order in profile.orders) ...[
                _OrderCard(
                  order: order,
                  products: profile.products,
                  branches: profile.branches,
                  onRepeat: () async {
                    final result = await controller.repeatOrder(order);
                    if (!context.mounted) return;
                    switch (result) {
                      case RepeatOrderResult.success:
                        showTopNotice(
                          context,
                          message: strings.orderAddedToCart,
                          actionLabel: strings.cart,
                          onAction: () => context.go('/cart'),
                        );
                        context.go('/cart');
                      case RepeatOrderResult.legacyOrder:
                        _showRepeatMessage(
                          context,
                          strings.profileLegacyOrderRepeatUnavailable,
                        );
                      case RepeatOrderResult.catalogUnavailable:
                        _showRepeatMessage(
                          context,
                          strings.profileRepeatNeedsServerCatalog,
                        );
                      case RepeatOrderResult.unavailableSelection:
                        _showRepeatMessage(
                          context,
                          strings.profileRepeatSelectionUnavailable,
                        );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 16),
            Text(strings.profileAddresses, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _AddressCard(
              label: strings.profileHomeAddressLabel,
              line: strings.profileHomeAddress,
            ),
            const SizedBox(height: 8),
            _AddressCard(
              label: strings.profileOfficeAddressLabel,
              line: strings.profileOfficeAddress,
            ),
            const SizedBox(height: 24),
            Text(
              strings.profileHelpAccountTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _HelpAndAccountCard(
              onLogout: () {
                controller.logout();
                context.go('/');
              },
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _confirmDelete(context, controller),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(strings.profileDeleteAccount),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStateController controller,
  ) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.profileDeleteAccountTitle),
        content: Text(strings.profileDeleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.profileCancelDelete),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.profileConfirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await controller.deleteAccount();
    if (!context.mounted) return;
    switch (result) {
      case AccountDeletionResult.success:
        context.go('/');
      case AccountDeletionResult.rejected:
        showTopNotice(
          context,
          message: strings.profileDeleteSessionExpired,
          actionLabel: strings.close,
          onAction: () {},
        );
      case AccountDeletionResult.unavailable:
        showTopNotice(
          context,
          message: strings.profileDeleteAccountFailed,
          actionLabel: strings.close,
          onAction: () {},
        );
      case AccountDeletionResult.busy:
        break;
    }
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.userContact,
  });

  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String userContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final hasName = firstName.trim().isNotEmpty || lastName.trim().isNotEmpty;
    final userName = '$firstName $lastName'.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ProfileAvatar(
              firstName: firstName,
              lastName: lastName,
              avatarUrl: avatarUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? userName : strings.profileAddName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    userContact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/profile/edit'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(strings.profileEditAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
  });

  final String firstName;
  final String lastName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = avatarUrl?.trim();
    final initials = _initials(firstName, lastName);
    final fallback = initials.isEmpty
        ? const Icon(Icons.person_outline, size: 34)
        : Text(
            initials,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          );

    return Semantics(
      image: true,
      label: AppLocalizations.of(context).profileAvatarLabel,
      child: CircleAvatar(
        radius: 36,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: url == null || url.isEmpty
            ? fallback
            : ClipOval(
                child: Image.network(
                  url,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  cacheWidth: 256,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    width: 72,
                    height: 72,
                    child: Center(child: fallback),
                  ),
                ),
              ),
      ),
    );
  }
}

String _initials(String firstName, String lastName) {
  final parts = [
    firstName.trim(),
    lastName.trim(),
  ].where((part) => part.isNotEmpty).take(2);
  return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
}

class _PointsEntry extends StatelessWidget {
  const _PointsEntry({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 14,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          strings.profilePointsTitle,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          strings.profilePointsEntryHint(
            formatPoints(points, strings.language),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/loyalty'),
      ),
    );
  }
}

class _HelpAndAccountCard extends StatelessWidget {
  const _HelpAndAccountCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(strings.profileSupportTitle),
            subtitle: Text(strings.profileSupportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/support'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.help_outline),
            title: Text(strings.profileFaqTitle),
            subtitle: Text(strings.profileFaqSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/faq'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.logout),
            title: Text(strings.profileLogout),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _LanguageMenuButton extends StatelessWidget {
  const _LanguageMenuButton({required this.language, required this.onSelected});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: strings.interfaceLanguage,
      child: PopupMenuButton<AppLanguage>(
        tooltip: strings.interfaceLanguage,
        initialValue: language,
        onSelected: onSelected,
        icon: const Icon(Icons.language),
        itemBuilder: (context) => [
          for (final option in AppLanguage.values)
            CheckedPopupMenuItem<AppLanguage>(
              value: option,
              checked: option == language,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      option.shortLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(option.nativeName),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return IconButton(
      onPressed: onPressed,
      tooltip: isDark
          ? strings.profileUseLightTheme
          : strings.profileUseDarkTheme,
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({
    required this.recurring,
    required this.products,
    required this.branches,
  });

  final RecurringOrder? recurring;
  final List<Product> products;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final activeRecurring = recurring;
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
              ],
            ),
            const SizedBox(height: 8),
            if (activeRecurring == null) ...[
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
            ] else
              _RecurringActive(
                recurring: activeRecurring,
                products: products,
                branches: branches,
              ),
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
    final productNames = recurring.productIds
        .map((productId) {
          final product = products
              .where((candidate) => candidate.id == productId)
              .firstOrNull;
          return product == null
              ? strings.recurringProductUnavailable(productId)
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
            '$paidUntilLabel',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final cancelled = await ref
                    .read(appStateProvider.notifier)
                    .cancelRecurring();
                if (!context.mounted || cancelled) return;
                _showRepeatMessage(context, strings.recurringCancelFailed);
              },
              child: Text(strings.recurringCancel),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.products,
    required this.branches,
    required this.onRepeat,
  });

  final OrderHistoryEntry order;
  final List<Product> products;
  final List<Branch> branches;
  final Future<void> Function() onRepeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final branch = branches
        .where((candidate) => candidate.id == order.branchId)
        .firstOrNull;
    final branchLabel = branch == null
        ? strings.profileUnknownBranch(order.branchId)
        : strings.branchName(branch);
    final itemLabels = order.items
        .map((item) {
          final currentProduct = item.productId == null
              ? null
              : products
                    .where((candidate) => candidate.id == item.productId)
                    .firstOrNull;
          final productName = currentProduct == null
              ? item.productName.resolve(strings.language)
              : strings.productName(currentProduct);
          final sizeName = item.sizeName?.resolve(strings.language);
          return <String>[
            productName,
            if (sizeName != null && sizeName.isNotEmpty) sizeName,
            if (item.quantity > 1) '×${item.quantity}',
          ].join(' · ');
        })
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.number, style: theme.textTheme.titleMedium),
                ),
                _StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${strings.orderTypeLabel(order.type)} · '
              '$branchLabel · '
              '${strings.readyTimeLabel(order.readyTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(itemLabels, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatSom(order.total, strings.language),
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (order.supportsExactRepeat)
                  TextButton.icon(
                    onPressed: onRepeat,
                    icon: const Icon(Icons.replay, size: 18),
                    label: Text(strings.profileRepeatOrder),
                  ),
              ],
            ),
            if (!order.supportsExactRepeat) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.profileLegacyOrderRepeatUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final isActive =
        status == OrderStatus.preparing || status == OrderStatus.ready;
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        strings.orderStatusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.label, required this.line});

  final String label;
  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        minTileHeight: 56,
        leading: Icon(
          Icons.location_on_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(label, style: theme.textTheme.titleSmall),
        subtitle: Text(line),
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
