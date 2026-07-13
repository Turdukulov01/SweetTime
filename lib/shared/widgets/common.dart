import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';

/// Логотип-марка бренда — круг акцентного цвета с первой буквой названия.
/// Название и акцент приходят из состояния (API или дефолт SweetTime).
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.size = 44, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(appStateProvider.select((s) => s.appName));
    final letter = appName.isEmpty
        ? 'S'
        : appName.substring(0, 1).toUpperCase();
    final theme = Theme.of(context);
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(appName, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

/// Заголовок секции с необязательной кнопкой-«смотреть все».
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? overline;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(
                  overline!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              if (overline != null) const SizedBox(height: 4),
              Text(title, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Пустое состояние (корзина, поиск, история).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Крупная карточка-сегмент для выбора (филиал, способ, оплата, план) — тап-зона ≥44px.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Степпер количества (−/n/＋).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          onPressed: onIncrement,
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
