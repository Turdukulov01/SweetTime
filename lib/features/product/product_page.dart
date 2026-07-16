import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/demo_data.dart';
import '../../shared/widgets/drink_art.dart';
import '../../shared/widgets/top_notice.dart';

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  String? _sizeId;
  int _sugarPercent = 50;
  IceLevel _ice = IceLevel.regular;
  final Set<String> _toppingIds = {};
  String? _configuredProductId;

  void _syncSelections(Product product) {
    final isNewProduct = _configuredProductId != product.id;
    _configuredProductId = product.id;

    if (isNewProduct || !product.sizes.any((size) => size.id == _sizeId)) {
      if (product.sizes.isEmpty) {
        _sizeId = null;
      } else {
        _sizeId = product.sizes.any((size) => size.id == 'm')
            ? 'm'
            : product.sizes.first.id;
      }
    }

    final availableToppingIds = product.toppings
        .map((topping) => topping.id)
        .toSet();
    if (isNewProduct) {
      _toppingIds
        ..clear()
        ..addAll(
          availableToppingIds.contains('tapioca')
              ? const {'tapioca'}
              : const <String>{},
        );
    } else {
      _toppingIds.removeWhere((id) => !availableToppingIds.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final language = state.language;
    final productImageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1024)
            .toInt();
    final product = state.products.firstWhere((p) => p.id == widget.productId);
    final isFavorite = state.favoriteIds.contains(product.id);
    _syncSelections(product);

    final available = product.availableIn(state.selectedBranch);
    final selectedSize = product.sizes.isEmpty
        ? null
        : product.sizes.firstWhere((size) => size.id == _sizeId);
    final sizeDelta = selectedSize?.priceDelta ?? 0;
    final toppingsDelta = product.toppings
        .where((topping) => _toppingIds.contains(topping.id))
        .fold(0, (sum, t) => sum + t.priceDelta);
    final total = product.basePrice + sizeDelta + toppingsDelta;
    final canAdd = available && (product.sizes.isEmpty || selectedSize != null);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/catalog'),
        ),
        actions: [
          IconButton(
            tooltip: isFavorite
                ? strings.removeFromFavorites
                : strings.addToFavorites,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? theme.colorScheme.primary : null,
            ),
            onPressed: () => controller.toggleFavorite(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: product.accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.assetImage != null
                ? Image.asset(
                    product.assetImage!,
                    fit: BoxFit.cover,
                    cacheWidth: productImageCacheWidth,
                    filterQuality: FilterQuality.low,
                  )
                : DrinkArt(product: product),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (product.isNew) _Chip(strings.newBadge),
              if (product.isBestSeller) _Chip(strings.bestSellerBadge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.name.resolve(language),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: product.accentColor),
              const SizedBox(width: 4),
              Text(
                '${product.rating} · ${strings.reviewCount(product.reviewsCount)}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.description.resolve(language),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          if (!available) ...[
            const SizedBox(height: 16),
            _UnavailableBanner(
              branchName: state.selectedBranch.name.resolve(language),
            ),
          ],

          const SizedBox(height: 24),
          _GroupLabel(strings.sizeLabel),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final size in product.sizes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _OptionButton(
                      label: size.name.resolve(language),
                      selected: selectedSize?.id == size.id,
                      onTap: () => setState(() => _sizeId = size.id),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          _GroupLabel(strings.iceLabel),
          const SizedBox(height: 10),
          _WrapOptions<IceLevel>(
            options: DemoData.iceLevels,
            selected: {_ice},
            labelFor: strings.iceLevelLabel,
            onTap: (value) => setState(() => _ice = value),
          ),

          const SizedBox(height: 20),
          _GroupLabel(strings.sugarLabel),
          const SizedBox(height: 10),
          _WrapOptions<int>(
            options: DemoData.sugarLevels,
            selected: {_sugarPercent},
            labelFor: (value) => '$value%',
            onTap: (value) => setState(() => _sugarPercent = value),
          ),

          const SizedBox(height: 20),
          _GroupLabel(strings.toppingsLabel),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final topping in product.toppings)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: _toppingIds.contains(topping.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _toppingIds.add(topping.id);
                    } else {
                      _toppingIds.remove(topping.id);
                    }
                  }),
                  title: Text(topping.name.resolve(language)),
                  secondary: Text(
                    '+${formatSom(topping.priceDelta, language)}',
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: canAdd
                ? () async {
                    final added = await controller.addConfigured(
                      product,
                      sizeId: selectedSize?.id,
                      sugarPercent: _sugarPercent,
                      ice: _ice,
                      toppingIds: _toppingIds.toList(),
                    );
                    if (!context.mounted || !added) return;
                    showTopNotice(
                      context,
                      message: strings.productAdded(
                        product.name.resolve(language),
                      ),
                      actionLabel: strings.cart,
                      onAction: () => context.go('/cart'),
                    );
                    context.go('/cart');
                  }
                : null,
            child: Text(
              available && selectedSize != null
                  ? strings.addToCartWithPrice(formatSom(total, language))
                  : strings.productUnavailableAction,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

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

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
      ),
    );
  }
}

class _WrapOptions<T> extends StatelessWidget {
  const _WrapOptions({
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onTap,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelFor(option)),
            selected: selected.contains(option),
            onSelected: (_) => onTap(option),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({required this.branchName});

  final String branchName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).productUnavailableAtBranch(branchName),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
