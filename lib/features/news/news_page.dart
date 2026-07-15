import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';
import 'news_media.dart';

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (
          collections: state.storyCollections,
          posts: state.newsPosts,
          language: state.language,
        ),
      ),
    );
    final strings = AppLocalizations.of(context);
    final now = DateTime.now().toUtc();
    final collections =
        state.collections
            .where((collection) => collection.isPublished)
            .toList(growable: false)
          ..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            return order == 0 ? left.id.compareTo(right.id) : order;
          });
    final posts =
        state.posts
            .where((post) => post.isActiveAt(now))
            .toList(growable: false)
          ..sort(_comparePosts);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () => ref
              .read(appStateProvider.notifier)
              .refreshCompanyData(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollCacheExtent: const ScrollCacheExtent.pixels(480),
            slivers: [
              SliverAppBar.large(pinned: true, title: Text(strings.news)),
              if (collections.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(title: strings.storyCollections),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CollectionRail(
                    collections: collections,
                    language: state.language,
                  ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(title: strings.newsFeed),
                ),
              ),
              if (posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.newspaper_outlined,
                    title: strings.newsFeedEmptyTitle,
                    message: strings.newsFeedEmptyMessage,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _NewsPostCard(
                        key: ValueKey('news-post-${posts[index].id}'),
                        post: posts[index],
                        language: state.language,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int _comparePosts(NewsPost left, NewsPost right) {
  final leftDate = left.publishedDate;
  final rightDate = right.publishedDate;
  if (leftDate != null && rightDate != null) {
    final date = rightDate.compareTo(leftDate);
    if (date != 0) return date;
  }
  return left.id.compareTo(right.id);
}

class _CollectionRail extends StatelessWidget {
  const _CollectionRail({required this.collections, required this.language});

  final List<StoryCollection> collections;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: collections.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 92,
            child: InkWell(
              key: ValueKey('story-collection-${collection.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/news/collection/${collection.id}'),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          collection.accentColor,
                          collection.accentColor.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: ClipOval(
                      child: NewsMediaView(
                        mediaType: collection.coverImageUrl == null
                            ? NewsMediaType.none
                            : NewsMediaType.image,
                        url: collection.coverImageUrl,
                        allowVideo: false,
                        aspectRatio: 1,
                        borderRadius: BorderRadius.zero,
                        fallbackIcon: collection.visual.icon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    collection.name.resolve(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  const _NewsPostCard({super.key, required this.post, required this.language});

  final NewsPost post;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = post.publishedDate;
    final summary = post.summary.resolve(language).trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openPost(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.effectiveMediaType != NewsMediaType.none)
              NewsMediaView(
                mediaType: post.effectiveMediaType,
                url: post.effectiveMediaUrl,
                thumbnailUrl: post.thumbnailUrl,
                allowVideo: false,
                borderRadius: BorderRadius.zero,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.resolve(language),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(date.toLocal()),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

  Future<void> _openPost(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _NewsPostSheet(post: post, language: language),
    );
  }
}

class _NewsPostSheet extends StatelessWidget {
  const _NewsPostSheet({required this.post, required this.language});

  final NewsPost post;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: SingleChildScrollView(
        key: const ValueKey('news-post-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.effectiveMediaType != NewsMediaType.none) ...[
              NewsMediaView(
                mediaType: post.effectiveMediaType,
                url: post.effectiveMediaUrl,
                thumbnailUrl: post.thumbnailUrl,
                allowVideo: true,
              ),
              const SizedBox(height: 20),
            ],
            Text(
              post.title.resolve(language),
              style: theme.textTheme.headlineMedium,
            ),
            if (post.publishedDate case final date?) ...[
              const SizedBox(height: 8),
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(date.toLocal()),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              post.body.resolve(language),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}
