import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../news/news_media.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/branded_background.dart';
import '../../shared/widgets/fullscreen_image.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/top_notice.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (
          products: state.products,
          promotions: state.promotions,
          newsStories: state.newsStories,
          language: state.language,
          selectedBranch: state.selectedBranch,
          branches: state.branches,
          appName: state.appName,
          apiConnected: state.apiConnected,
          accentColor: state.accentColor,
          logoUrl: state.logoThumbnailUrl ?? state.logoUrl,
          viewedStoryIds: state.viewedStoryIds,
        ),
      ),
    );
    final controller = ref.read(appStateProvider.notifier);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);

    final bestSellers = state.products.where((p) => p.isBestSeller).toList();
    final fresh = state.products.where((p) => p.isNew).toList();
    final newsStories = selectHomeStories(state.newsStories);

    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator.adaptive(
            onRefresh: () => controller.refreshCompanyData(force: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Build roughly two product rows ahead. The Home feed contains only a
              // small curated set, so this keeps image decoding out of the visible
              // scroll path without retaining the full catalog.
              scrollCacheExtent: const ScrollCacheExtent.pixels(720),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopBar(
                    language: state.language,
                    onToggleTheme: controller.toggleTheme,
                    onLanguageSelected: controller.setLanguage,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _BranchSelector(
                    selectedBranch: state.selectedBranch,
                    branches: state.branches,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Hero(onOrder: () => context.go('/catalog')),
                ),

                // Пустой промо-блок скрываем целиком (критерий приёмки UX-брифа).
                if (state.promotions.isNotEmpty) ...[
                  _sectionPadding(
                    SectionHeader(
                      overline: strings.today,
                      title: strings.seasonalOffers,
                      actionLabel: strings.all,
                      onAction: () => context.go('/catalog'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _PromoRail(promotions: state.promotions),
                  ),
                ],

                if (newsStories.isNotEmpty) ...[
                  _sectionPadding(
                    SectionHeader(
                      overline: strings.news,
                      title: strings.whatsNew,
                      actionIcon: Icons.arrow_forward_rounded,
                      actionTooltip: strings.openNews,
                      onAction: () => context.push('/news'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _NewsStoryRail(
                      stories: newsStories,
                      language: state.language,
                      accentColor: state.accentColor,
                      logoUrl: state.logoUrl,
                      viewedStoryIds: state.viewedStoryIds,
                    ),
                  ),
                ],

                _sectionPadding(
                  SectionHeader(
                    overline: strings.popular,
                    title: strings.bestSellers,
                    actionLabel: strings.all,
                    onAction: () => context.go('/catalog'),
                  ),
                ),
                _ProductGrid(products: bestSellers, controller: controller),

                _sectionPadding(
                  SectionHeader(
                    overline: strings.newItems,
                    title: strings.newOnMenu,
                  ),
                ),
                _ProductGrid(products: fresh, controller: controller),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.footer(state.appName),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.dataSource(state.apiConnected),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverPadding _sectionPadding(Widget child) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.language,
    required this.onToggleTheme,
    required this.onLanguageSelected,
  });

  final AppLanguage language;
  final VoidCallback onToggleTheme;
  final ValueChanged<AppLanguage> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          // Expanded (вместо Spacer): логотип+название занимают левую зону и
          // сжимаются, когда её мало, а язык/тема прижаты вправо как раньше.
          const Expanded(child: _TappableLogo()),
          PopupMenuButton<AppLanguage>(
            tooltip: strings.interfaceLanguage,
            initialValue: language,
            onSelected: onLanguageSelected,
            itemBuilder: (context) => [
              for (final language in AppLanguage.values)
                PopupMenuItem(
                  value: language,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          language.shortLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(language.nativeName),
                    ],
                  ),
                ),
            ],
            child: Semantics(
              button: true,
              label: strings.interfaceLanguage,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  language.shortLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

/// Логотип в шапке: тап открывает его на весь экран с зумом. Если у компании
/// нет своего логотипа, увеличивается дефолтная иконка-заглушка.
class _TappableLogo extends ConsumerWidget {
  const _TappableLogo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Для зума на весь экран берём полноразмерный логотип, а не миниатюру.
    final logoUrl = ref.watch(
      appStateProvider.select((s) => s.logoUrl ?? s.logoThumbnailUrl),
    );
    return GestureDetector(
      onTap: () => showFullscreenImage(
        context,
        imageProvider: (logoUrl != null && logoUrl.isNotEmpty)
            ? NetworkImage(logoUrl)
            : null,
        fallback: Icon(
          Icons.storefront_rounded,
          size: 160,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: const AppLogo(size: 48, showWordmark: true),
    );
  }
}

class _BranchSelector extends ConsumerWidget {
  const _BranchSelector({required this.selectedBranch, required this.branches});

  final Branch selectedBranch;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showBranchPicker(context, ref),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${strings.branch}: '),
                    TextSpan(
                      text: selectedBranch.name.resolve(strings.language),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _showBranchPicker(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).chooseBranch,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final branch in branches)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(branch.name.resolve(strings.language)),
                subtitle: Text(
                  '${branch.address.resolve(strings.language)} · ${branch.hours}',
                ),
                trailing: branch.id == selectedBranch.id
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(appStateProvider.notifier).selectBranch(branch);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOrder});

  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.9),
              theme.colorScheme.primary.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                strings.pointsForEveryOrder,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              strings.heroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.heroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOrder,
              icon: const Icon(Icons.arrow_forward),
              label: Text(strings.orderDrinks),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoRail extends StatelessWidget {
  const _PromoRail({required this.promotions});

  final List<Promotion> promotions;

  @override
  Widget build(BuildContext context) {
    final language = AppLocalizations.of(context).language;
    return SizedBox(
      // Высота рельсы растёт с крупным шрифтом (кламп 0.9–1.3 в main), но не
      // сжимается ниже базовой — иначе текст акции переполняет карточку.
      height: 168 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: promotions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final promo = promotions[index];
          return _PromoCard(
            promo: promo,
            language: language,
            onTap: () => _openPromoDetail(context, promo, language),
          );
        },
      ),
    );
  }
}

void _openPromoDetail(
  BuildContext context,
  Promotion promo,
  AppLanguage language,
) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PromoDetailView(promo: promo, language: language),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.promo,
    required this.language,
    required this.onTap,
  });

  final Promotion promo;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = promo.thumbnailUrl ?? promo.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final title = promo.title.resolve(language).trim();
    final description = promo.description.resolve(language).trim();
    final hasCopy =
        title.isNotEmpty || description.isNotEmpty || promo.code.isNotEmpty;

    return GestureDetector(
      key: ValueKey('promo-card-${promo.id}'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Only the image flies into the detail view (Hero) — an icon
              // placeholder growing wouldn't read as "opening a promo".
              if (hasImage)
                Hero(
                  tag: 'promo-image-${promo.id}',
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              if (hasImage && hasCopy)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                    ),
                  ),
                ),
              if (!hasImage || hasCopy)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasImage)
                        Icon(
                          Icons.local_activity_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      const Spacer(),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: hasImage ? Colors.white : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasImage
                                ? Colors.white.withValues(alpha: .9)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (promo.code.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasImage
                                ? Colors.black.withValues(alpha: .38)
                                : theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            promo.code,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: hasImage ? Colors.white : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoDetailView extends StatelessWidget {
  const _PromoDetailView({required this.promo, required this.language});

  final Promotion promo;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = promo.imageUrl ?? promo.thumbnailUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final title = promo.title.resolve(language).trim();
    final description = promo.description.resolve(language).trim();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        if (hasImage)
                          Hero(
                            tag: 'promo-image-${promo.id}',
                            child: Image.network(
                              imageUrl,
                              height: 260,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 260,
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                            ),
                          )
                        else
                          Container(
                            height: 200,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.local_activity_outlined,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton.filled(
                            key: const ValueKey('promo-detail-close'),
                            onPressed: Navigator.of(context).pop,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.45,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(description, style: theme.textTheme.bodyLarge),
                          ],
                          if (promo.code.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                promo.code,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsStoryRail extends StatelessWidget {
  const _NewsStoryRail({
    required this.stories,
    required this.language,
    required this.accentColor,
    required this.logoUrl,
    required this.viewedStoryIds,
  });

  final List<NewsStory> stories;
  final AppLanguage language;
  final Color accentColor;
  final String? logoUrl;
  final Set<String> viewedStoryIds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Высота растёт с крупным шрифтом, но не сжимается ниже базовой.
      height: 124 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          final viewed = viewedStoryIds.contains(story.id);
          return SizedBox(
            width: 88,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/news/story/${story.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    Container(
                      key: ValueKey('story-ring-${story.id}'),
                      width: 74,
                      height: 74,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: viewed
                            ? null
                            : LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.45),
                                ],
                              ),
                        border: viewed
                            ? Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              )
                            : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: NewsMediaView(
                            mediaType: story.effectiveMediaType,
                            url: story.effectiveMediaUrl,
                            thumbnailUrl: story.thumbnailUrl,
                            fallbackImageUrl: logoUrl,
                            assetImage: story.assetImage,
                            allowVideo: false,
                            aspectRatio: 1,
                            borderRadius: BorderRadius.zero,
                            fallbackIcon: story.visual.icon,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      story.title.resolve(language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.controller});

  final List<Product> products;
  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 16);
    final strings = AppLocalizations.of(context);
    return SliverPadding(
      padding: padding,
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
            return ProductCard(
              key: ValueKey(product.id),
              product: product,
              onTap: () => context.push('/product/${product.id}'),
              onAdd: () async {
                final added = await controller.quickAdd(product);
                if (!context.mounted || !added) return;
                showTopNotice(
                  context,
                  message: strings.productAdded(
                    product.name.resolve(strings.language),
                  ),
                  actionLabel: strings.cart,
                  onAction: () => context.go('/cart'),
                );
              },
            );
          },
          childCount: products.length,
          // ProductCard is stateless and stores favorite/cart state in
          // Riverpod, so keep-alive wrappers add work without preserving UI.
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}
