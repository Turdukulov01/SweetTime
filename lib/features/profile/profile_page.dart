import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/fullscreen_image.dart';
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
          orders: state.visibleOrders,
          products: state.products,
          branches: state.branches,
          selectedBranch: state.selectedBranch,
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
            const SizedBox(height: 12),
            _OrderHistoryEntry(orders: profile.orders),
            const SizedBox(height: 16),
            _BranchesEntry(
              branches: profile.branches,
              selectedBranch: profile.selectedBranch,
              onSelected: controller.selectBranch,
            ),
            const SizedBox(height: 24),
            Text('Оформление', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const _BackgroundEntry(),
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

    final hasPhoto = url != null && url.isNotEmpty;

    final avatar = Semantics(
      image: true,
      label: AppLocalizations.of(context).profileAvatarLabel,
      child: CircleAvatar(
        radius: 36,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: !hasPhoto
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

    // Открываем на весь экран только когда есть реальное фото — на кружке с
    // инициалами рассматривать нечего.
    if (!hasPhoto) return avatar;
    return GestureDetector(
      onTap: () => showFullscreenImage(
        context,
        imageProvider: NetworkImage(url),
        heroTag: 'profile-avatar',
        fallback: fallback,
      ),
      child: Hero(tag: 'profile-avatar', child: avatar),
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

/// Выбор фона: `null` — как задано в админке, свой узор или выключить совсем.
/// Пока RU-строки заданы прямо здесь; локализация — отдельной задачей.
const _backgroundOptions = <({String? value, String label, IconData icon})>[
  (value: null, label: 'Как в приложении', icon: Icons.auto_awesome_outlined),
  (value: 'bubbles', label: 'Пузырьки', icon: Icons.bubble_chart_outlined),
  (value: 'coffee', label: 'Кофе', icon: Icons.coffee_outlined),
  (value: 'off', label: 'Без фона', icon: Icons.block_outlined),
];

class _BackgroundEntry extends ConsumerWidget {
  const _BackgroundEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(
      appStateProvider.select((s) => s.backgroundOverride),
    );
    final current = _backgroundOptions.firstWhere(
      (o) => o.value == override,
      orElse: () => _backgroundOptions.first,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.wallpaper_outlined),
        title: const Text('Фон приложения'),
        subtitle: Text(current.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickBackground(context, ref, override),
      ),
    );
  }

  Future<void> _pickBackground(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final selected = await showModalBottomSheet<({String? value})>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Фон приложения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final option in _backgroundOptions)
              ListTile(
                leading: Icon(option.icon),
                title: Text(option.label),
                trailing: option.value == current
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, (value: option.value)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    ref.read(appStateProvider.notifier).setBackgroundOverride(selected.value);
  }
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

class _OrderHistoryEntry extends StatelessWidget {
  const _OrderHistoryEntry({required this.orders});

  final List<OrderHistoryEntry> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final latest = orders.firstOrNull;
    return Card(
      child: ListTile(
        key: const ValueKey('profile-order-history-entry'),
        minTileHeight: 72,
        onTap: () => context.push('/profile/orders'),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.receipt_long_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          strings.profileOrderHistory,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          latest == null
              ? strings.profileOrderHistoryEmptyCompact
              : strings.profileOrderHistorySummary(
                  orders.length,
                  strings.orderStatusLabel(latest.status),
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Semantics(
          label: strings.profileOpenOrderHistory,
          child: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _BranchesEntry extends StatelessWidget {
  const _BranchesEntry({
    required this.branches,
    required this.selectedBranch,
    required this.onSelected,
  });

  final List<Branch> branches;
  final Branch selectedBranch;
  final ValueChanged<Branch> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        minTileHeight: 72,
        leading: Icon(
          Icons.storefront_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          strings.profileOurBranches,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(strings.profileOurBranchesHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  strings.profileOurBranches,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final branch in branches)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(branch.name.resolve(strings.language)),
                      subtitle: Text(
                        '${branch.address.resolve(strings.language)} · ${branch.hours}',
                      ),
                      trailing: branch.id == selectedBranch.id
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        onSelected(branch);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
