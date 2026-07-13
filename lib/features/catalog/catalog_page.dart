import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  final Set<String> _selectedCategoryIds = <String>{};
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategoryIds.clear();
      _favoritesOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (
          products: state.products,
          categories: state.categories,
          language: state.language,
          appName: state.appName,
        ),
      ),
    );
    final favoriteIds = _favoritesOnly
        ? ref.watch(appStateProvider.select((state) => state.favoriteIds))
        : ref.read(appStateProvider).favoriteIds;
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final language = state.language;

    final filtered = state.products.where((p) {
      final matchesCategory =
          _selectedCategoryIds.isEmpty ||
          _selectedCategoryIds.contains(p.category.id);
      final matchesFavorites = !_favoritesOnly || favoriteIds.contains(p.id);
      final q = _query.trim().toLowerCase();
      final localizedName = p.name.resolve(language).toLowerCase();
      final localizedDescription = p.description
          .resolve(language)
          .toLowerCase();
      final matchesTopping = p.toppings.any(
        (topping) => topping.name.resolve(language).toLowerCase().contains(q),
      );
      final matchesQuery =
          q.isEmpty ||
          localizedName.contains(q) ||
          localizedDescription.contains(q) ||
          matchesTopping;
      return matchesCategory && matchesFavorites && matchesQuery;
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          // Prepare roughly two rows before they enter the viewport so image
          // decode/layout work does not land on the visible scroll frame.
          scrollCacheExtent: const ScrollCacheExtent.pixels(680),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.catalog,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.catalogSubtitle(state.appName),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: strings.catalogSearchHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(strings.all),
                        selected: _selectedCategoryIds.isEmpty,
                        showCheckmark: false,
                        onSelected: (_) => setState(_selectedCategoryIds.clear),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        label: strings.favoritesFilterSemantics,
                        selected: _favoritesOnly,
                        child: FilterChip(
                          avatar: const Icon(Icons.favorite, size: 18),
                          label: Text(strings.favoritesFilter),
                          selected: _favoritesOnly,
                          showCheckmark: false,
                          onSelected: (selected) =>
                              setState(() => _favoritesOnly = selected),
                        ),
                      ),
                    ),
                    for (final category in state.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.name.resolve(language)),
                          selected: _selectedCategoryIds.contains(category.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedCategoryIds.add(category.id);
                            } else {
                              _selectedCategoryIds.remove(category.id);
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: _favoritesOnly
                      ? Icons.favorite_border
                      : Icons.search_off,
                  title: _favoritesOnly
                      ? strings.favoritesEmptyTitle
                      : strings.catalogEmptyTitle,
                  message: _favoritesOnly
                      ? strings.favoritesEmptyMessage
                      : strings.catalogEmptyMessage,
                  action: FilledButton(
                    onPressed: _resetFilters,
                    child: Text(strings.resetFilters),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 330,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = filtered[index];
                      return ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                        onTap: () => context.go('/product/${product.id}'),
                        onAdd: () {
                          controller.quickAdd(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.productAdded(
                                  product.name.resolve(language),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: filtered.length,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
