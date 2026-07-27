import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

/// Лист настройки постоянного заказа: любимые напитки/комбо → время → филиал → предоплата.
///
/// При редактировании сервер пересчитывает ещё не сформированные выдачи и
/// возвращает demo-доплату либо кредит. Уже созданный заказ на сегодня не
/// переписывается задним числом.
Future<void> showRecurringSheet(
  BuildContext context,
  WidgetRef ref, {
  RecurringOrder? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RecurringSheet(existing: existing),
  );
}

enum _RecurringAction { edit, purchase }

const _maxRecurringProducts = 20;

class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet({this.existing});

  final RecurringOrder? existing;

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  final Set<String> _productIds = {};
  final TextEditingController _commentController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);
  late Branch _branch;
  RecurringPlan _plan = RecurringPlan.week;
  DateTime? _customUntil;
  _RecurringAction? _pending;
  String? _requestFingerprint;
  String? _requestIdempotencyKey;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _branch = state.selectedBranch;
    final recurring = widget.existing;
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
      _customUntil = recurring.customUntil;
      _commentController.text = recurring.comment ?? '';
    } else if (state.favorites.isNotEmpty) {
      _productIds.add(state.favorites.first.id);
    }
    // Кнопка «Сохранить изменения» активируется по факту правок, включая текст.
    _commentController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _stableTime =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  bool _sameProductSet(RecurringOrder recurring) =>
      _productIds.length == recurring.productIds.length &&
      recurring.productIds.every(_productIds.contains);

  bool _sameDate(DateTime? left, DateTime? right) =>
      left?.year == right?.year &&
      left?.month == right?.month &&
      left?.day == right?.day;

  bool _hasEdits(RecurringOrder recurring) =>
      !_sameProductSet(recurring) ||
      _stableTime != recurring.time ||
      _branch.id != recurring.branchId ||
      _plan != recurring.plan ||
      (_plan == RecurringPlan.custom &&
          !_sameDate(_customUntil, recurring.customUntil)) ||
      _commentController.text.trim() != (recurring.comment ?? '');

  int get _customOccurrences {
    final until = _customUntil;
    if (until == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(until.year, until.month, until.day);
    final daysAhead = end.difference(today).inDays;
    if (daysAhead < 1) return 0;
    final todayMoment = DateTime(
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    return daysAhead + (todayMoment.isAfter(now) ? 1 : 0);
  }

  String? get _customUntilFingerprint {
    final value = _customUntil;
    if (value == null) return null;
    return '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickCustomUntil() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day + 1);
    final lastDate = DateTime(now.year, now.month, now.day + 366);
    final selected = await showDatePicker(
      context: context,
      initialDate: _customUntil == null ||
              _customUntil!.isBefore(firstDate) ||
              _customUntil!.isAfter(lastDate)
          ? DateTime(now.year, now.month, now.day + 7)
          : _customUntil!,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected != null) setState(() => _customUntil = selected);
  }

  String _idempotencyKeyFor(String fingerprint) {
    if (_requestFingerprint != fingerprint || _requestIdempotencyKey == null) {
      final random = Random.secure();
      final instant = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      final entropy = List.generate(
        3,
        (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
      ).join();
      _requestFingerprint = fingerprint;
      _requestIdempotencyKey = 'recurring-mobile-$instant-$entropy';
    }
    return _requestIdempotencyKey!;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final activeRecurring = widget.existing == null
        ? null
        : state.recurringOrders
                  .where((item) => item.id == widget.existing!.id)
                  .firstOrNull ??
              widget.existing;
    final combo = state.products
        .where((p) => _productIds.contains(p.id))
        .toList();
    final selectableProducts = state.products
        .where(
          (product) =>
              product.availableIn(_branch) || _productIds.contains(product.id),
        )
        .toList(growable: false);
    final catalogProductIds = state.products
        .map((product) => product.id)
        .toSet();
    final lockedItemsByProductId = <String, RecurringOrderItem>{
      for (final item in activeRecurring?.items ?? const <RecurringOrderItem>[])
        item.productId: item,
    };
    final missingSelectedProductIds = _productIds
        .where((productId) => !catalogProductIds.contains(productId))
        .toList(growable: false);
    // Для активной подписки с неизменённым составом верна серверная цена дня
    // (сервер уже учёл текущие цены каталога); для черновика — локальная сумма.
    final localDailyPrice = combo.fold(
      0,
      (sum, product) => sum + _defaultRecurringPrice(product),
    );
    final dailyPrice =
        activeRecurring != null && _sameProductSet(activeRecurring)
        ? activeRecurring.dailyTotal
        : localDailyPrice;
    final planOccurrences = _plan == RecurringPlan.custom
        ? _customOccurrences
        : _plan.days;
    final planTotal = dailyPrice * planOccurrences;
    final hasEdits = activeRecurring != null && _hasEdits(activeRecurring);
    final hasClosedBranch = !_branch.isOpen;
    final hasUnavailableProducts =
        missingSelectedProductIds.isNotEmpty ||
        combo.any((product) => !product.availableIn(_branch));
    final hasTooManyProducts = _productIds.length > _maxRecurringProducts;

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
                      '${formatSom(_defaultRecurringPrice(product), strings.language)}',
                    ),
                    selected: _productIds.contains(product.id),
                    onSelected:
                        !_productIds.contains(product.id) &&
                            _productIds.length >= _maxRecurringProducts
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _productIds.add(product.id);
                            } else {
                              _productIds.remove(product.id);
                            }
                          }),
                  ),
                for (final productId in missingSelectedProductIds)
                  FilterChip(
                    label: Text(
                      '${lockedItemsByProductId[productId]?.name.resolve(strings.language) ?? strings.recurringProductUnavailable(productId)} · '
                      '${formatSom(lockedItemsByProductId[productId]?.total ?? 0, strings.language)}',
                    ),
                    selected: true,
                    onSelected: (selected) {
                      if (!selected) {
                        setState(() => _productIds.remove(productId));
                      }
                    },
                  ),
              ],
            ),
            if (combo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                strings.recurringDailyPrice(
                  formatSom(dailyPrice, strings.language),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (hasUnavailableProducts) ...[
              const SizedBox(height: 8),
              Text(
                strings.recurringUnavailableForBranch,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_productIds.length >= _maxRecurringProducts) ...[
              const SizedBox(height: 8),
              Text(
                strings.recurringProductLimit(_maxRecurringProducts),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasTooManyProducts
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

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
            for (final branch in state.branches.where(
              (branch) => branch.isOpen,
            ))
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
            if (hasClosedBranch)
              Text(
                strings.recurringClosedBranch,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
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
                  onTap: () => setState(() {
                    _plan = plan;
                    if (plan == RecurringPlan.custom &&
                        _customUntil == null) {
                      final now = DateTime.now();
                      _customUntil = DateTime(
                        now.year,
                        now.month,
                        now.day + 7,
                      );
                    }
                  }),
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
                              '${formatSom(
                                dailyPrice *
                                    (plan == RecurringPlan.custom
                                        ? _customOccurrences
                                        : plan.days),
                                strings.language,
                              )}',
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
            if (_plan == RecurringPlan.custom) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _pending == null ? _pickCustomUntil : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _customUntil == null
                      ? strings.recurringChooseEndDate
                      : strings.recurringCustomUntil(_customUntil!),
                ),
              ),
            ],

            const SizedBox(height: 20),
            _StepLabel(strings.recurringCommentLabel),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: strings.baristaCommentHint),
            ),

            const SizedBox(height: 12),
            if (activeRecurring != null) ...[
              // V2 applies all changes to this subscription ID. The server
              // locks the price and returns a signed demo top-up/credit.
              FilledButton(
                onPressed:
                    combo.isEmpty ||
                        hasUnavailableProducts ||
                        hasClosedBranch ||
                        hasTooManyProducts ||
                        (_plan == RecurringPlan.custom &&
                            _customUntil == null) ||
                        _pending != null ||
                        !hasEdits
                    ? null
                    : () => _submitEdit(strings, activeRecurring, combo),
                child: _pending == _RecurringAction.edit
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.recurringSaveChanges),
              ),
            ] else
              FilledButton(
                onPressed:
                    combo.isEmpty ||
                        hasUnavailableProducts ||
                        hasClosedBranch ||
                        hasTooManyProducts ||
                        (_plan == RecurringPlan.custom &&
                            _customUntil == null) ||
                        _pending != null
                    ? null
                    : () => _submitPurchase(strings, combo),
                child: _pending == _RecurringAction.purchase
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

  Future<void> _submitEdit(
    AppLocalizations strings,
    RecurringOrder active,
    List<Product> combo,
  ) async {
    final stableTime = _stableTime;
    final comment = _commentController.text.trim();
    final commentChanged = comment != (active.comment ?? '');
    final fingerprint = [
      'edit',
      active.id,
      active.version,
      ...(_productIds.toList()..sort()),
      stableTime,
      _branch.id,
      _plan.name,
      _customUntilFingerprint ?? '',
      comment,
    ].join('|');
    setState(() => _pending = _RecurringAction.edit);
    final saved = await ref
        .read(appStateProvider.notifier)
        .editRecurring(
          recurringId: active.id,
          products: _sameProductSet(active) ? null : combo,
          time: stableTime == active.time ? null : stableTime,
          branch: _branch.id == active.branchId ? null : _branch,
          plan: _plan == active.plan ? null : _plan,
          customUntil:
              _plan == RecurringPlan.custom &&
                  (!_sameDate(_customUntil, active.customUntil) ||
                      active.plan != RecurringPlan.custom)
              ? _customUntil
              : null,
          comment: commentChanged ? comment : null,
          commentProvided: commentChanged,
          idempotencyKey: _idempotencyKeyFor(fingerprint),
        );
    final updated = ref
        .read(appStateProvider)
        .recurringOrders
        .where((item) => item.id == active.id)
        .firstOrNull;
    final adjustment = updated?.lastAdjustment ?? 0;
    final successMessage = adjustment > 0
        ? strings.recurringDemoTopUp(formatSom(adjustment, strings.language))
        : adjustment < 0
        ? strings.recurringMoneyCredit(formatSom(-adjustment, strings.language))
        : strings.recurringChangesSaved;
    _finishSubmit(saved: saved, successMessage: successMessage);
  }

  Future<void> _submitPurchase(
    AppLocalizations strings,
    List<Product> combo,
  ) async {
    final comment = _commentController.text.trim();
    final fingerprint = [
      'create',
      ...(_productIds.toList()..sort()),
      _stableTime,
      _branch.id,
      _plan.name,
      _customUntilFingerprint ?? '',
      comment,
    ].join('|');
    setState(() => _pending = _RecurringAction.purchase);
    final saved = await ref
        .read(appStateProvider.notifier)
        .setRecurring(
          products: combo,
          time: _stableTime,
          branch: _branch,
          plan: _plan,
          customUntil: _plan == RecurringPlan.custom ? _customUntil : null,
          comment: comment,
          idempotencyKey: _idempotencyKeyFor(fingerprint),
        );
    _finishSubmit(saved: saved, successMessage: strings.recurringEnabledDemo);
  }

  void _finishSubmit({required bool saved, required String successMessage}) {
    if (!mounted) return;
    setState(() => _pending = null);
    final strings = AppLocalizations.of(context);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.recurringSaveFailed)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }
}

int _defaultRecurringPrice(Product product) =>
    product.basePrice + (product.sizes.firstOrNull?.priceDelta ?? 0);

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
