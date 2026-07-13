import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';

class NewsStoryPage extends ConsumerStatefulWidget {
  const NewsStoryPage({super.key, required this.initialStoryId});

  final String initialStoryId;

  @override
  ConsumerState<NewsStoryPage> createState() => _NewsStoryPageState();
}

class _NewsStoryPageState extends ConsumerState<NewsStoryPage> {
  PageController? _pageController;
  int _currentIndex = 0;

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
    final stories =
        state.newsStories
            .where((story) => story.isActiveAt(DateTime.now()))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (stories.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(strings.news)),
      );
    }

    if (_pageController == null) {
      final requestedIndex = stories.indexWhere(
        (story) => story.id == widget.initialStoryId,
      );
      _currentIndex = requestedIndex < 0 ? 0 : requestedIndex;
      _pageController = PageController(initialPage: _currentIndex);
    }

    final current = stories[_currentIndex.clamp(0, stories.length - 1)];
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
                controller: _pageController,
                itemCount: stories.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (details.localPosition.dx <
                        MediaQuery.sizeOf(context).width / 2) {
                      _previous();
                    } else {
                      _nextOrClose(stories.length);
                    }
                  },
                  child: _StoryContent(
                    story: stories[index],
                    language: state.language,
                    foreground: foreground,
                    position: index + 1,
                    total: stories.length,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                right: 64,
                child: Row(
                  children: [
                    for (var index = 0; index < stories.length; index++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _currentIndex
                                ? foreground
                                : foreground.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      if (index != stories.length - 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 8,
                child: IconButton(
                  tooltip: strings.close,
                  onPressed: () => Navigator.of(context).pop(),
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previous() {
    if (_currentIndex == 0) return;
    _pageController?.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _nextOrClose(int storyCount) {
    if (_currentIndex >= storyCount - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pageController?.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    required this.story,
    required this.language,
    required this.foreground,
    required this.position,
    required this.total,
  });

  final NewsStory story;
  final AppLanguage language;
  final Color foreground;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 84, 28, 36),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 150,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$position / $total',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 36),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(story.visual.icon, size: 54, color: foreground),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                story.badge.resolve(language),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              story.title.resolve(language),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              story.body.resolve(language),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
