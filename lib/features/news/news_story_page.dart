import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _NewsStoryPageState extends ConsumerState<NewsStoryPage>
    with SingleTickerProviderStateMixin {
  static const _imageDuration = Duration(seconds: 6);
  static const _videoFallbackDuration = Duration(seconds: 15);

  PageController? _pageController;
  late final AnimationController _progressController;
  List<NewsStory>? _collectionStories;
  List<NewsStory> _renderedStories = const [];
  int _currentIndex = 0;
  int _restartEpoch = 0;
  bool _loading = false;
  bool _loadFailed = false;
  bool _held = false;
  bool _navigating = false;
  bool _currentVideoReady = false;
  bool _videoEndedWhileHeld = false;
  Duration _currentVideoPosition = Duration.zero;
  Duration _currentVideoDuration = Duration.zero;
  int _videoEndSequence = 0;
  String? _scheduledPlaybackKey;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _imageDuration,
    )..addStatusListener(_handleProgressStatus);
    if (widget.collectionId != null) _loadCollection();
  }

  @override
  void didUpdateWidget(covariant NewsStoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId) {
      _pageController?.dispose();
      _pageController = null;
      _currentIndex = 0;
      _restartEpoch++;
      _collectionStories = null;
      _scheduledPlaybackKey = null;
      _progressController.stop();
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
    final fallback = ref
        .read(appStateProvider)
        .newsStories
        .where((story) => story.collectionId == collectionId)
        .toList(growable: false);
    final stories = List<NewsStory>.of(loaded ?? fallback)
      ..sort(compareNewsStories);
    setState(() {
      _collectionStories = stories;
      _loading = false;
      _loadFailed = loaded == null && fallback.isEmpty;
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _progressController.dispose();
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
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.newsLoadFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
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
    _renderedStories = stories;
    final safeIndex = _currentIndex.clamp(0, stories.length - 1);
    final current = stories[safeIndex];
    _schedulePlayback(current);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: ValueKey('story-pages-${widget.collectionId ?? 'home'}'),
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) => _StoryContent(
                key: ValueKey(
                  'story-content-${stories[index].id}-${index == safeIndex ? _restartEpoch : 0}',
                ),
                story: stories[index],
                language: state.language,
                isCurrent: index == safeIndex,
                playbackPaused: _held,
                onVideoReady: index == safeIndex
                    ? (duration) => _handleVideoReady(stories[index], duration)
                    : null,
                onVideoProgress: index == safeIndex
                    ? (position, duration) => _handleVideoProgress(
                        stories[index],
                        position,
                        duration,
                      )
                    : null,
                onVideoEnded: index == safeIndex
                    ? () => _handleVideoEnded(stories[index])
                    : null,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('story-navigation-gesture'),
                behavior: HitTestBehavior.translucent,
                onTapUp: _handleTap,
                onLongPressStart: (_) => _holdPlayback(),
                onLongPressEnd: (_) => _resumePlayback(),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => _StoryProgress(
                        count: stories.length,
                        currentIndex: safeIndex,
                        currentValue: _progressController.value,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const ValueKey('story-close'),
                        tooltip: strings.close,
                        onPressed: context.pop,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.26),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_held)
              const Center(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(
                        Icons.pause_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

  void _schedulePlayback(NewsStory story) {
    final key = '${story.id}:$_restartEpoch';
    if (_scheduledPlaybackKey == key) return;
    _scheduledPlaybackKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledPlaybackKey != key) return;
      _activateStory(story);
    });
  }

  void _activateStory(NewsStory story) {
    _progressController.stop();
    _currentVideoReady = false;
    _videoEndedWhileHeld = false;
    _currentVideoPosition = Duration.zero;
    _currentVideoDuration = Duration.zero;
    _videoEndSequence++;
    _progressController.duration = _isVideo(story)
        ? _videoFallbackDuration
        : _imageDuration;
    _progressController.value = 0;
    if (!_held) _progressController.forward();
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _held) return;
    final current = _currentStory;
    if (current == null) return;
    if (_isVideo(current) && _currentVideoReady) return;
    _advance();
  }

  NewsStory? get _currentStory {
    if (_renderedStories.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _renderedStories.length) {
      return null;
    }
    return _renderedStories[_currentIndex];
  }

  bool _isVideo(NewsStory story) =>
      story.effectiveMediaType == NewsMediaType.video &&
      (story.effectiveMediaUrl?.trim().isNotEmpty ?? false);

  void _handlePageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _held = false;
    });
  }

  void _handleTap(TapUpDetails details) {
    if (_held || _navigating) return;
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx < width / 2) {
      _previous();
    } else {
      _advance();
    }
  }

  void _previous() {
    if (_currentIndex <= 0) {
      _restartCurrentStory();
      return;
    }
    _animateTo(_currentIndex - 1);
  }

  void _advance() {
    if (_navigating || !mounted) return;
    if (_currentIndex >= _renderedStories.length - 1) {
      context.pop();
      return;
    }
    _animateTo(_currentIndex + 1);
  }

  Future<void> _animateTo(int index) async {
    final controller = _pageController;
    if (controller == null || !controller.hasClients || _navigating) return;
    _navigating = true;
    _progressController.stop();
    try {
      await controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _navigating = false;
    }
  }

  void _restartCurrentStory() {
    setState(() {
      _restartEpoch++;
      _held = false;
      _scheduledPlaybackKey = null;
    });
  }

  void _holdPlayback() {
    if (_held || !mounted) return;
    setState(() => _held = true);
    _progressController.stop();
  }

  void _resumePlayback() {
    if (!_held || !mounted) return;
    setState(() => _held = false);
    final current = _currentStory;
    if (current == null) return;
    if (_videoEndedWhileHeld) {
      _scheduleVideoAdvance(current);
    } else if (_isVideo(current) && _currentVideoReady) {
      _animateVideoProgressToEnd();
    } else {
      _progressController.forward();
    }
  }

  void _handleVideoReady(NewsStory story, Duration duration) {
    if (!mounted ||
        _currentStory?.id != story.id ||
        duration <= Duration.zero) {
      return;
    }
    _currentVideoReady = true;
    _currentVideoPosition = Duration.zero;
    _currentVideoDuration = duration;
    _progressController.stop();
    _progressController.duration = duration;
    _progressController.value = 0;
    if (!_held) _animateVideoProgressToEnd();
  }

  void _handleVideoProgress(
    NewsStory story,
    Duration position,
    Duration duration,
  ) {
    if (!mounted ||
        _currentStory?.id != story.id ||
        duration <= Duration.zero) {
      return;
    }
    _currentVideoPosition = position;
    _currentVideoDuration = duration;
    final value = position.inMilliseconds / duration.inMilliseconds;
    final synchronizedValue = value.clamp(0.0, 1.0);
    if ((_progressController.value - synchronizedValue).abs() > 0.02) {
      _progressController.value = synchronizedValue;
    }
    if (!_held && synchronizedValue < 1) _animateVideoProgressToEnd();
  }

  void _handleVideoEnded(NewsStory story) {
    if (!mounted || _currentStory?.id != story.id) return;
    _progressController.value = 1;
    _videoEndedWhileHeld = true;
    if (!_held) _scheduleVideoAdvance(story);
  }

  void _scheduleVideoAdvance(NewsStory story) {
    final sequence = ++_videoEndSequence;
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (!mounted ||
          sequence != _videoEndSequence ||
          _currentStory?.id != story.id ||
          _held) {
        return;
      }
      _videoEndedWhileHeld = false;
      _advance();
    });
  }

  void _animateVideoProgressToEnd() {
    final remaining = _currentVideoDuration - _currentVideoPosition;
    if (remaining <= Duration.zero) {
      _progressController.value = 1;
      return;
    }
    _progressController.animateTo(1, duration: remaining, curve: Curves.linear);
  }
}

class _StoryProgress extends StatelessWidget {
  const _StoryProgress({
    required this.count,
    required this.currentIndex,
    required this.currentValue,
  });

  final int count;
  final int currentIndex;
  final double currentValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < count; index++) ...[
          Expanded(
            child: LinearProgressIndicator(
              key: index == currentIndex
                  ? const ValueKey('story-progress-current')
                  : null,
              value: index < currentIndex
                  ? 1
                  : index == currentIndex
                  ? currentValue
                  : 0,
              minHeight: 4,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (index != count - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    super.key,
    required this.story,
    required this.language,
    required this.isCurrent,
    required this.playbackPaused,
    this.onVideoReady,
    this.onVideoProgress,
    this.onVideoEnded,
  });

  final NewsStory story;
  final AppLanguage language;
  final bool isCurrent;
  final bool playbackPaused;
  final ValueChanged<Duration>? onVideoReady;
  final void Function(Duration position, Duration duration)? onVideoProgress;
  final VoidCallback? onVideoEnded;

  @override
  Widget build(BuildContext context) {
    final badge = story.badge.resolve(language).trim();
    final title = story.title.resolve(language).trim();
    final body = story.body.resolve(language).trim();
    final hasMedia =
        story.effectiveMediaType != NewsMediaType.none ||
        story.assetImage != null;

    return ColoredBox(
      key: ValueKey('story-current-${story.id}'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasMedia)
            NewsMediaView(
              mediaType: story.effectiveMediaType,
              url: story.effectiveMediaUrl,
              thumbnailUrl: story.thumbnailUrl,
              assetImage: story.assetImage,
              allowVideo: isCurrent,
              isActive: isCurrent,
              fallbackIcon: story.visual.icon,
              borderRadius: BorderRadius.zero,
              fit: BoxFit.contain,
              expand: true,
              backgroundColor: Colors.black,
              autoPlay: true,
              playbackPaused: playbackPaused,
              showPlaybackControls: false,
              initialMuted: false,
              onVideoReady: onVideoReady,
              onVideoProgress: onVideoProgress,
              onVideoEnded: onVideoEnded,
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    story.accentColor,
                    Color.lerp(story.accentColor, Colors.black, 0.36)!,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  story.visual.icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 92,
                ),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x52000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB8000000),
                  ],
                  stops: [0, 0.2, 0.55, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 110, 24, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge.isNotEmpty) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            badge,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                              shadows: const [
                                Shadow(blurRadius: 12, color: Colors.black87),
                              ],
                            ),
                      ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        body,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                          height: 1.32,
                          shadows: const [
                            Shadow(blurRadius: 10, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
