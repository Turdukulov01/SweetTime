import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../app_models.dart';
import '../app_state.dart';
import 'drink_art.dart';

/// Карточка напитка в каталоге/подборках. Открывает детальную по тапу.
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.availableAtSelectedBranch = true,
    this.onChooseBranch,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool availableAtSelectedBranch;
  final VoidCallback? onChooseBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final isFavorite = ref.watch(
      appStateProvider.select((s) => s.favoriteIds.contains(product.id)),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageUrl case final imageUrl?)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cacheWidth =
                            (constraints.biggest.longestSide *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil();
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: cacheWidth,
                          errorBuilder: (context, error, stackTrace) =>
                              _ProductFallback(product: product),
                        );
                      },
                    )
                  else if (product.assetImage case final assetImage?)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cacheWidth =
                            (constraints.biggest.longestSide *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil();
                        return Image.asset(
                          assetImage,
                          fit: BoxFit.cover,
                          cacheWidth: cacheWidth,
                        );
                      },
                    )
                  else
                    _ProductFallback(product: product),
                  if (!availableAtSelectedBranch)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (product.isNew) _Tag(strings.newBadge),
                        if (product.isBestSeller)
                          _Tag(
                            strings.hitBadge,
                            color: const Color(0xFFD8F8EA),
                            fg: const Color(0xFF251713),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: () => ref
                          .read(appStateProvider.notifier)
                          .toggleFavorite(product),
                      tooltip: isFavorite
                          ? strings.removeFromFavorites
                          : strings.addToFavorites,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? theme.colorScheme.primary
                            : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  if (!availableAtSelectedBranch)
                    Positioned(
                      left: 8,
                      right: 52,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            strings.unavailableAtBranchTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.resolve(strings.language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: product.accentColor,
                      ),
                      const SizedBox(width: 2),
                      // Expanded вместо Spacer: занимает слабину (цена вправо,
                      // как раньше), но на узкой карточке/крупном шрифте
                      // сжимается, а не переполняет ряд.
                      Expanded(
                        child: Text(
                          product.rating.toString(),
                          style: theme.textTheme.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          formatSom(product.startingPrice, strings.language),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (onAdd != null || !availableAtSelectedBranch) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: availableAtSelectedBranch
                            ? onAdd
                            : onChooseBranch,
                        icon: Icon(
                          availableAtSelectedBranch
                              ? Icons.add_shopping_cart
                              : Icons.storefront_outlined,
                          size: 18,
                        ),
                        label: Text(
                          availableAtSelectedBranch
                              ? strings.addToCart
                              : onChooseBranch == null
                              ? strings.productUnavailableEverywhere
                              : strings.chooseAvailableBranch,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
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
    );
  }
}

class _ProductFallback extends StatelessWidget {
  const _ProductFallback({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: product.accentColor.withValues(alpha: 0.14),
    child: DrinkArt(product: product),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color, this.fg});

  final String label;
  final Color? color;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg ?? Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
