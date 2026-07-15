import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import 'news_media.dart';

class NewsStoryPage extends ConsumerStatefulWidget {
  const NewsStoryPage({super.key, this.initialStoryId, this.collectionId})
    : assert(initialStoryId != null || collectionId != null);

  final String? initialStoryId;
  final String? collectionId;

  @override
  ConsumerState<NewsStoryPage> createState() => _NewsStoryPageState();
}

class _NewsStoryPageState extends ConsumerState<NewsStoryPage> {
  PageController? _pageController;
  List<NewsStory>? _collectionStories;
  int _currentIndex = 0;
  bool _loading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.collectionId != null) _loadCollection();
  }

  @override
  void didUpdateWidget(covariant NewsStoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId) {
      _pageController?.dispose();
      _pageController = null;
      _currentIndex = 0;
      _collectionStories = null;
      if (widget.collectionId != null) _loadCollection();
    }
  }

  Future<void> _loadCollection() async {
    final collectionId = widget.collectionId;
    if (collectionId == null) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final loaded = await ref
        .read(appStateProvider.notifier)
        .fetchCollectionStories(collectionId);
    if (!mounted || collectionId != widget.collectionId) return;
    final fallback =
        ref
            .read(appStateProvider)
            .newsStories
            .where((story) => story.collectionId == collectionId)
            .toList(growable: false)
          ..sort(compareNewsStories);
    setState(() {
      _collectionStories = loaded ?? fallback;
      _loading = false;
      _loadFailed = loaded == null && fallback.isEmpty;
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      appStateProvider.select(
        (state) => (newsStories: state.newsStories, language: state.language),
      ),
    );
    final strings = AppLocalizations.of(context);

    if (_loading && _collectionStories == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.newsLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadCollection,
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stories = widget.collectionId == null
        ? (state.newsStories
              .where((story) => story.isActiveAt(DateTime.now().toUtc()))
              .toList(growable: false)
            ..sort(compareNewsStories))
        : (_collectionStories ?? const <NewsStory>[]);
    if (stories.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(strings.collectionEmpty, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    _ensurePageController(stories);
    final safeIndex = _currentIndex.clamp(0, stories.length - 1);
    final current = stories[safeIndex];
    final foreground =
        ThemeData.estimateBrightnessForColor(current.accentColor) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF251713);

    return Scaffold(
      backgroundColor: current.accentColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              current.accentColor,
              Color.lerp(current.accentColor, Colors.black, 0.2)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                key: ValueKey('story-pages-${widget.collectionId ?? 'home'}'),
                controller: _pageController,
                itemCount: stories.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => _StoryContent(
                  story: stories[index],
                  language: state.language,
                  foreground: foreground,
                  isCurrent: index == safeIndex,
                ),
              ),
              Positioned(
                top: 12,
                left: 20,
                right: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (safeIndex + 1) / stories.length,
                      color: foreground,
                      backgroundColor: foreground.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${safeIndex + 1} / ${stories.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 8,
                child: IconButton(
                  tooltip: strings.close,
                  onPressed: context.pop,
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: safeIndex == 0 ? null : _previous,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    IconButton.filledTonal(
                      onPressed: safeIndex == stories.length - 1 ? null : _next,
                      icon: const Icon(Icons.arrow_forward_rounded),
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

  void _ensurePageController(List<NewsStory> stories) {
    if (_pageController != null) {
      if (_currentIndex >= stories.length) {
        _currentIndex = stories.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController?.hasClients == true) {
            _pageController!.jumpToPage(_currentIndex);
          }
        });
      }
      return;
    }
    final requestedIndex = widget.initialStoryId == null
        ? 0
        : stories.indexWhere((story) => story.id == widget.initialStoryId);
    _currentIndex = requestedIndex < 0 ? 0 : requestedIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _previous() {
    _pageController?.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    _pageController?.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    required this.story,
    required this.language,
    required this.foreground,
    required this.isCurrent,
  });

  final NewsStory story;
  final AppLanguage language;
  final Color foreground;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final badge = story.badge.resolve(language).trim();
    final body = story.body.resolve(language).trim();
    final cta = story.ctaLabel?.resolve(language).trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 84, 24, 84),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 190,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NewsMediaView(
              key: ValueKey('story-media-${story.id}-$isCurrent'),
              mediaType: story.effectiveMediaType,
              url: story.effectiveMediaUrl,
              thumbnailUrl: story.thumbnailUrl,
              assetImage: story.assetImage,
              allowVideo: isCurrent,
              isActive: isCurrent,
              fallbackIcon: story.visual.icon,
            ),
            if (badge.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              story.title.resolve(language),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                body,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            ],
            if (cta != null &&
                cta.isNotEmpty &&
                _isAllowedRoute(story.ctaRoute)) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(story.ctaRoute!),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(cta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isAllowedRoute(String? route) {
  if (route == null || !route.startsWith('/')) return false;
  return route == '/' ||
      route.startsWith('/catalog') ||
      route.startsWith('/qr') ||
      route.startsWith('/cart') ||
      route.startsWith('/profile') ||
      route.startsWith('/news');
}
