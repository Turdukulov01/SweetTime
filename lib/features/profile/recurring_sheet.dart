import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

/// Лист настройки постоянного заказа: любимые напитки/комбо → время → филиал → предоплата.
Future<void> showRecurringSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _RecurringSheet(),
  );
}

class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet();

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  final Set<String> _productIds = {};
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);
  late Branch _branch;
  RecurringPlan _plan = RecurringPlan.week;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _branch = state.selectedBranch;
    final recurring = state.recurring;
    if (recurring != null) {
      _productIds.addAll(recurring.productIds);
      final timeParts = recurring.time.split(':');
      if (timeParts.length == 2) {
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour != null && minute != null) {
          _time = TimeOfDay(hour: hour, minute: minute);
        }
      }
      _branch =
          state.branches
              .where((branch) => branch.id == recurring.branchId)
              .firstOrNull ??
          state.selectedBranch;
      _plan = recurring.plan;
    } else if (state.favorites.isNotEmpty) {
      _productIds.add(state.favorites.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final combo = state.products
        .where((p) => _productIds.contains(p.id))
        .toList();
    final selectableProducts = <Product>[
      ...state.favorites,
      ...state.products.where(
        (product) =>
            _productIds.contains(product.id) &&
            !state.favoriteIds.contains(product.id),
      ),
    ];
    final comboPrice = combo.fold(0, (sum, p) => sum + p.basePrice);
    final planTotal = comboPrice * _plan.days;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(
              strings.recurringOrderTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              strings.recurringSheetIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),
            _StepLabel(strings.recurringDrinksStep),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final product in selectableProducts)
                  FilterChip(
                    label: Text(
                      '${strings.productName(product)} · '
                      '${formatSom(product.basePrice, strings.language)}',
                    ),
                    selected: _productIds.contains(product.id),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _productIds.add(product.id);
                      } else {
                        _productIds.remove(product.id);
                      }
                    }),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            _StepLabel(strings.recurringReadyTimeStep),
            const SizedBox(height: 6),
            SelectableTile(
              selected: false,
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.access_time),
                  const SizedBox(width: 12),
                  Text(
                    strings.recurringReadyAt(_time.format(context)),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _StepLabel(strings.recurringBranchStep),
            const SizedBox(height: 10),
            for (final branch in state.branches)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableTile(
                  selected: branch.id == _branch.id,
                  onTap: () => setState(() => _branch = branch),
                  child: Text(
                    strings.branchName(branch),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),

            const SizedBox(height: 20),
            _StepLabel(strings.recurringPrepaymentStep),
            const SizedBox(height: 10),
            for (final plan in RecurringPlan.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableTile(
                  selected: _plan == plan,
                  onTap: () => setState(() => _plan = plan),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.recurringPlanLabel(plan),
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${strings.recurringPlanHint(plan)} · '
                              '${formatSom(comboPrice * plan.days, strings.language)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_plan == plan)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: combo.isEmpty || _saving
                  ? null
                  : () async {
                      final stableTime =
                          '${_time.hour.toString().padLeft(2, '0')}:'
                          '${_time.minute.toString().padLeft(2, '0')}';
                      setState(() => _saving = true);
                      final saved = await ref
                          .read(appStateProvider.notifier)
                          .setRecurring(
                            products: combo,
                            time: stableTime,
                            branch: _branch,
                            plan: _plan,
                          );
                      if (!mounted || !context.mounted) return;
                      setState(() => _saving = false);
                      if (!saved) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.recurringSaveFailed)),
                        );
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text(strings.recurringEnabledDemo)),
                      );
                    },
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      strings.recurringPayAndEnable(
                        formatSom(planTotal, strings.language),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}
