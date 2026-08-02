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
                // A feed video initializes only when its lazily-built card
                // enters the sliver cache. It stays paused on its first frame;
                // playback starts only in the detail viewer.
                allowVideo: post.effectiveMediaType == NewsMediaType.video,
                autoPlay: false,
                showPlaybackControls: false,
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
      // The full-screen media stage must begin below Android/iOS status
      // indicators instead of drawing the source video underneath them.
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewsPostSheet(post: post, language: language),
    );
  }
}

double adaptiveNewsVideoHeight({
  required double availableWidth,
  required double availableHeight,
  required double videoAspectRatio,
}) {
  if (availableWidth <= 0 || availableHeight <= 0) return 0;
  final safeAspectRatio = videoAspectRatio.isFinite && videoAspectRatio > 0
      ? videoAspectRatio
      : 9 / 16;
  return (availableWidth / safeAspectRatio).clamp(0.0, availableHeight);
}

class _NewsPostSheet extends StatefulWidget {
  const _NewsPostSheet({required this.post, required this.language});

  final NewsPost post;
  final AppLanguage language;

  @override
  State<_NewsPostSheet> createState() => _NewsPostSheetState();
}

class _NewsPostSheetState extends State<_NewsPostSheet> {
  double _videoAspectRatio = 9 / 16;
  bool _captionExpanded = false;

  NewsPost get post => widget.post;
  AppLanguage get language => widget.language;

  @override
  Widget build(BuildContext context) {
    if (post.effectiveMediaType == NewsMediaType.video) {
      return _buildVideoViewer(context);
    }

    return _buildRegularViewer(context);
  }

  Widget _buildVideoViewer(BuildContext context) {
    final theme = Theme.of(context);
    final title = post.title.resolve(language).trim();
    final body = post.body.resolve(language).trim().isNotEmpty
        ? post.body.resolve(language).trim()
        : post.summary.resolve(language).trim();
    final date = post.publishedDate;

    return FractionallySizedBox(
      heightFactor: 1,
      child: Material(
        key: const ValueKey('news-post-sheet'),
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Full available height, not aspect-locked: the stage always
            // reaches the true bottom edge (owner request), cropping via
            // BoxFit.cover instead of leaving a gap for short/landscape
            // sources. Top position is unchanged from before.
            final mediaHeight = constraints.maxHeight;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const ValueKey('news-post-video-stage'),
                width: double.infinity,
                height: mediaHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NewsMediaView(
                      key: ValueKey('news-post-media-${post.id}'),
                      mediaType: post.effectiveMediaType,
                      url: post.effectiveMediaUrl,
                      thumbnailUrl: post.thumbnailUrl,
                      allowVideo: true,
                      borderRadius: BorderRadius.zero,
                      // Stage is full-height (see mediaHeight above); cover
                      // crops top/bottom or sides as needed so there's never
                      // a gap, regardless of the source's native ratio.
                      fit: BoxFit.cover,
                      expand: true,
                      backgroundColor: Colors.black,
                      autoPlay: true,
                      showPlaybackControls: true,
                      tapToToggleMute: true,
                      initialMuted: true,
                      controlsBottomInset: title.isEmpty ? 18 : 92,
                      onVideoAspectRatio: _updateVideoAspectRatio,
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x33000000),
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xC7000000),
                              ],
                              stops: [0, 0.18, 0.58, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton.filled(
                        key: const ValueKey('news-post-close'),
                        onPressed: Navigator.of(context).pop,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.52),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    if (title.isNotEmpty || body.isNotEmpty || date != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ExpandableVideoCaption(
                          title: title,
                          body: body,
                          formattedDate: date == null
                              ? null
                              : MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(date.toLocal()),
                          expanded: _captionExpanded,
                          maxBodyHeight: mediaHeight * 0.3,
                          onToggle: () => setState(
                            () => _captionExpanded = !_captionExpanded,
                          ),
                          titleStyle: theme.textTheme.titleLarge,
                          bodyStyle: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateVideoAspectRatio(double value) {
    if (!mounted || !value.isFinite || value <= 0) return;
    if ((_videoAspectRatio - value).abs() < 0.001) return;
    setState(() => _videoAspectRatio = value);
  }

  Widget _buildRegularViewer(BuildContext context) {
    final theme = Theme.of(context);
    final mediaHeight = MediaQuery.sizeOf(context).height * 0.72;
    final hasMedia = post.effectiveMediaType != NewsMediaType.none;
    return FractionallySizedBox(
      heightFactor: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Material(
          key: const ValueKey('news-post-sheet'),
          color: theme.colorScheme.surface,
          child: CustomScrollView(
            slivers: [
              if (hasMedia)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: mediaHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NewsMediaView(
                          key: ValueKey('news-post-media-${post.id}'),
                          mediaType: post.effectiveMediaType,
                          url: post.effectiveMediaUrl,
                          thumbnailUrl: post.thumbnailUrl,
                          allowVideo: true,
                          borderRadius: BorderRadius.zero,
                          fit: BoxFit.contain,
                          expand: true,
                          backgroundColor: Colors.black,
                          autoPlay:
                              post.effectiveMediaType == NewsMediaType.video,
                          showPlaybackControls: true,
                          tapToToggleMute:
                              post.effectiveMediaType == NewsMediaType.video,
                          initialMuted:
                              post.effectiveMediaType == NewsMediaType.video,
                        ),
                        SafeArea(
                          bottom: false,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: IconButton.filled(
                                key: const ValueKey('news-post-close'),
                                onPressed: Navigator.of(context).pop,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.52,
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: IconButton(
                          key: const ValueKey('news-post-close'),
                          onPressed: Navigator.of(context).pop,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList.list(
                  children: [
                    Text(
                      post.title.resolve(language),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandableVideoCaption extends StatelessWidget {
  const _ExpandableVideoCaption({
    required this.title,
    required this.body,
    required this.formattedDate,
    required this.expanded,
    required this.maxBodyHeight,
    required this.onToggle,
    required this.titleStyle,
    required this.bodyStyle,
  });

  final String title;
  final String body;
  final String? formattedDate;
  final bool expanded;
  final double maxBodyHeight;
  final VoidCallback onToggle;
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;

  bool get _hasDetails => body.isNotEmpty || formattedDate != null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('news-post-video-caption'),
          onTap: _hasDetails ? onToggle : null,
          // The chevron already communicates expanded/collapsed state — the
          // default ink splash/highlight over a black video reads as a
          // flashing white rectangle, so it's fully disabled here.
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 42, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            key: const ValueKey('news-post-video-title'),
                            maxLines: expanded ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(blurRadius: 10, color: Colors.black87),
                              ],
                            ),
                          ),
                        ),
                        if (_hasDetails) ...[
                          const SizedBox(width: 8),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  if (expanded) ...[
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxBodyHeight.clamp(72, 280),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            body,
                            key: const ValueKey('news-post-video-body'),
                            style: bodyStyle?.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                              height: 1.35,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black87),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (formattedDate case final value?) ...[
                      const SizedBox(height: 10),
                      Text(
                        value,
                        key: const ValueKey('news-post-video-date'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black87),
                              ],
                            ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
