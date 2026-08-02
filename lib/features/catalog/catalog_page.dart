import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/branch_picker.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/top_notice.dart';

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
  bool _showAllBranches = false;

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
          branches: state.branches,
          selectedBranch: state.selectedBranch,
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
    final availableProducts = filtered
        .where(
          (product) =>
              state.selectedBranch.isOpen &&
              product.availableIn(state.selectedBranch),
        )
        .toList(growable: false);
    final unavailableProducts = filtered
        .where(
          (product) =>
              !state.selectedBranch.isOpen ||
              !product.availableIn(state.selectedBranch),
        )
        .toList(growable: false);

    Future<void> addProduct(Product product) async {
      final added = await controller.quickAdd(product);
      if (!context.mounted) return;
      if (!added) {
        showTopNotice(
          context,
          message: strings.productAddFailed,
          actionLabel: strings.retry,
          onAction: () => controller.refreshCompanyData(force: true),
        );
        return;
      }
      showTopNotice(
        context,
        message: strings.productAdded(product.name.resolve(language)),
        actionLabel: strings.cart,
        onAction: () => context.go('/cart'),
      );
    }

    Future<void> chooseCatalogBranch() async {
      final branch = await showBranchPicker(
        context,
        branches: state.branches,
        selectedBranch: state.selectedBranch,
      );
      if (!context.mounted || branch == null) return;
      controller.selectBranch(branch);
      setState(() => _showAllBranches = false);
    }

    Future<void> chooseBranchForProduct(Product product) async {
      final branch = await showBranchPicker(
        context,
        branches: state.branches,
        selectedBranch: state.selectedBranch,
        availableBranchIds: product.availableBranchIds.toSet(),
        title: strings.chooseBranchForProduct(product.name.resolve(language)),
      );
      if (!context.mounted || branch == null) return;
      controller.selectBranch(branch);
      setState(() => _showAllBranches = false);
      showTopNotice(
        context,
        message: strings.branchSelectedForProduct(
          branch.name.resolve(language),
          product.name.resolve(language),
        ),
        actionLabel: strings.addToCart,
        onAction: () => addProduct(product),
      );
    }

    SliverPadding section(String title, {String? message}) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    SliverPadding productGrid(List<Product> products) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 330,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            final available =
                state.selectedBranch.isOpen &&
                product.availableIn(state.selectedBranch);
            final hasAvailableBranch = state.branches.any(
              (branch) => branch.isOpen && product.availableIn(branch),
            );
            return ProductCard(
              key: ValueKey(product.id),
              product: product,
              availableAtSelectedBranch: available,
              onTap: () => context.push('/product/${product.id}'),
              onAdd: available ? () => addProduct(product) : null,
              onChooseBranch: !available && hasAvailableBranch
                  ? () => chooseBranchForProduct(product)
                  : null,
            );
          },
          childCount: products.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () => controller.refreshCompanyData(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      const SizedBox(height: 14),
                      Text(
                        strings.catalogBranchScope,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            key: const ValueKey('catalog-my-branch-filter'),
                            avatar: const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                            ),
                            label: Text(
                              strings.myBranch(
                                state.selectedBranch.name.resolve(language),
                              ),
                            ),
                            selected: !_showAllBranches,
                            showCheckmark: false,
                            onSelected: (_) {
                              if (_showAllBranches) {
                                setState(() => _showAllBranches = false);
                              } else {
                                chooseCatalogBranch();
                              }
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('catalog-all-branches-filter'),
                            label: Text(strings.allBranches),
                            selected: _showAllBranches,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _showAllBranches = true),
                          ),
                        ],
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
                          onSelected: (_) =>
                              setState(_selectedCategoryIds.clear),
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
                            selected: _selectedCategoryIds.contains(
                              category.id,
                            ),
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
              else if (_showAllBranches) ...[
                section(
                  strings.allBranches,
                  message: strings.allBranchesHint(
                    state.selectedBranch.name.resolve(language),
                  ),
                ),
                productGrid(filtered),
              ] else ...[
                if (availableProducts.isNotEmpty) ...[
                  section(
                    strings.availableAtBranch(
                      state.selectedBranch.name.resolve(language),
                    ),
                  ),
                  productGrid(availableProducts),
                ],
                if (unavailableProducts.isNotEmpty) ...[
                  section(
                    strings.unavailableAtBranchTitle,
                    message: strings.unavailableAtBranchHint(
                      state.selectedBranch.name.resolve(language),
                    ),
                  ),
                  productGrid(unavailableProducts),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
