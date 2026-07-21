import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sweettime/core/api_client.dart';
import 'package:sweettime/core/auth_store.dart';
import 'package:sweettime/core/cart_store.dart';
import 'package:sweettime/core/localization/app_localizations.dart';
import 'package:sweettime/core/story_view_store.dart';
import 'package:sweettime/core/theme/app_theme.dart';
import 'package:sweettime/features/news/news_page.dart';
import 'package:sweettime/features/news/news_story_page.dart';
import 'package:sweettime/features/home/home_page.dart';
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';
import 'package:sweettime/shared/demo_data.dart';

void main() {
  test('home stories are pinned, newest first and capped at 30', () {
    final stories = [
      for (var index = 0; index < 35; index++)
        _story(
          'story-$index',
          DateTime.utc(2025, 1, 1).add(Duration(days: index)),
        ),
      _story('pinned', DateTime.utc(2020), isPinned: true),
    ];

    final selected = selectHomeStories(
      stories,
      now: DateTime.utc(2026),
      limit: 99,
    );

    expect(selected, hasLength(30));
    expect(selected.first.id, 'pinned');
    expect(selected[1].id, 'story-34');
    expect(selected.last.id, 'story-6');
  });

  test('home selector removes hidden, future and expired stories', () {
    final now = DateTime.utc(2026, 7, 15);
    final selected = selectHomeStories([
      _story('active', DateTime.utc(2026, 7, 14)),
      _story('hidden', DateTime.utc(2026, 7, 14), showOnHome: false),
      _story('future', DateTime.utc(2026, 7, 16)),
      NewsStory(
        id: 'expired',
        title: const LocalizedText(ru: 'Expired'),
        body: const LocalizedText(ru: ''),
        badge: const LocalizedText(ru: ''),
        accentHex: 0xFFFF5A96,
        visual: NewsStoryVisual.sparkle,
        publishedAt: '2026-07-01T00:00:00Z',
        expiresAt: '2026-07-15T00:00:00Z',
        sortOrder: 0,
      ),
    ], now: now);

    expect(selected.map((story) => story.id), ['active']);
  });

  test('V2 mappers preserve stable IDs, localization and media', () {
    final story = ApiClient.mapNewsStory({
      'id': 'story-stable-42',
      'collectionId': 'collection-a',
      'title': {'ru': 'Заголовок', 'ky': 'Аталышы', 'en': 'Title'},
      'body': {'ru': 'Текст', 'ky': 'Текст', 'en': 'Body'},
      'badge': {'ru': 'Новое', 'ky': 'Жаңы', 'en': 'New'},
      'accentColor': '#112233',
      'visual': 'qr',
      'publishedAt': '2026-07-01T00:00:00Z',
      'showOnHome': true,
      'isPinned': true,
      'mediaType': 'video',
      'mediaUrl': 'https://cdn.example/story.mp4',
      'thumbnailUrl': 'https://cdn.example/story.webp',
    });
    final collection = ApiClient.mapStoryCollection({
      'id': 'collection-a',
      'name': {'ru': 'Лето', 'ky': 'Жай', 'en': 'Summer'},
      'sortOrder': 4,
    });
    final post = ApiClient.mapNewsPost({
      'id': 'post-17',
      'title': {'ru': 'Новость', 'ky': 'Жаңылык', 'en': 'News'},
      'summary': {'ru': 'Кратко', 'ky': 'Кыскача', 'en': 'Summary'},
      'body': {'ru': 'Полный текст', 'ky': 'Толук текст', 'en': 'Full body'},
      'publishedAt': '2026-07-01T00:00:00Z',
      'mediaType': 'image',
      'mediaUrl': 'https://cdn.example/post.webp',
    });

    expect(story.id, 'story-stable-42');
    expect(story.collectionId, 'collection-a');
    expect(story.title.resolve(AppLanguage.ky), 'Аталышы');
    expect(story.isPinned, isTrue);
    expect(story.effectiveMediaType, NewsMediaType.video);
    expect(collection.id, 'collection-a');
    expect(collection.name.resolve(AppLanguage.en), 'Summer');
    expect(post.id, 'post-17');
    expect(post.body.resolve(AppLanguage.en), 'Full body');
    expect(post.effectiveMediaType, NewsMediaType.image);

    final mediaOnlyStory = ApiClient.mapNewsStory({
      'id': 'story-media-only',
      'title': {'ru': '', 'ky': '', 'en': ''},
      'body': {'ru': '', 'ky': '', 'en': ''},
      'badge': {'ru': '', 'ky': '', 'en': ''},
      'publishedAt': '2026-07-01T00:00:00Z',
      'mediaType': 'image',
      'mediaUrl': 'https://cdn.example/media-only.webp',
    });
    for (final language in AppLanguage.values) {
      expect(mediaOnlyStory.title.resolve(language), isEmpty);
    }
  });

  testWidgets(
    'collection supports 40+ stories and Android back returns to news',
    (tester) async {
      final harness = await _pumpNewsApp(tester);
      addTearDown(harness.dispose);

      expect(
        find.byKey(const ValueKey('story-collection-large')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('story-collection-large')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.childrenDelegate.estimatedChildCount, 45);
      expect(
        find.byKey(const ValueKey('story-current-collection-story-44')),
        findsOneWidget,
      );
      expect(
        harness.controller.state.viewedStoryIds,
        contains('collection-story-44'),
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);

      final progressFinder = find.byKey(
        const ValueKey('story-progress-current'),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final before = tester
          .widget<LinearProgressIndicator>(progressFinder)
          .value!;
      await tester.pump(const Duration(milliseconds: 600));
      final moving = tester
          .widget<LinearProgressIndicator>(progressFinder)
          .value!;
      expect(moving, greaterThan(before));

      final gestureFinder = find.byKey(
        const ValueKey('story-navigation-gesture'),
      );
      final gestureRect = tester.getRect(gestureFinder);
      final hold = await tester.startGesture(gestureRect.center);
      await tester.pump(const Duration(milliseconds: 600));
      final held = tester
          .widget<LinearProgressIndicator>(progressFinder)
          .value!;
      await tester.pump(const Duration(seconds: 1));
      final stillHeld = tester
          .widget<LinearProgressIndicator>(progressFinder)
          .value!;
      expect(stillHeld, closeTo(held, 0.0001));
      await hold.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      final resumed = tester
          .widget<LinearProgressIndicator>(progressFinder)
          .value!;
      expect(resumed, greaterThan(stillHeld));

      await tester.tapAt(
        Offset(
          gestureRect.left + gestureRect.width * 0.8,
          gestureRect.center.dy,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('story-current-collection-story-43')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const ValueKey('story-collection-large')),
        findsOneWidget,
      );
    },
  );

  test('viewed story state survives controller recreation', () async {
    final store = _MemoryStoryViewStore();
    final first = _newsController(store);
    await first.bootstrap();
    await first.markStoryViewed('story-persisted');

    final restored = _newsController(store);
    await restored.bootstrap();

    expect(restored.state.viewedStoryIds, {'story-persisted'});
  });

  testWidgets('home story ring uses brand accent then becomes neutral', (
    tester,
  ) async {
    final story = _story('home-ring', DateTime.utc(2026, 7, 15));
    final controller = AppStateController(
      api: _NewsApi(homeStories: [story], accentColor: const Color(0xFFEE7722)),
      languagePreferences: _MemoryPreferences(),
      authStore: _MemoryAuthStore(),
      cartStore: _MemoryCartStore(),
      storyViewStore: _MemoryStoryViewStore(),
    );
    await controller.bootstrap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStateProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: AppTheme.light(const Color(0xFFEE7722)),
          locale: const Locale('en'),
          supportedLocales: [
            for (final language in AppLanguage.values) language.locale,
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    BoxDecoration decoration() =>
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('story-ring-home-ring')),
                )
                .decoration!
            as BoxDecoration;

    expect(decoration().gradient, isA<LinearGradient>());
    expect(
      (decoration().gradient! as LinearGradient).colors.first,
      const Color(0xFFEE7722),
    );

    await controller.markStoryViewed(story.id);
    await tester.pump();

    expect(decoration().gradient, isNull);
    expect(decoration().border, isNotNull);
  });

  testWidgets('news post sheet closes with Android back', (tester) async {
    final harness = await _pumpNewsApp(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('news-post-post-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('news-post-sheet')), findsOneWidget);
    expect(find.text('Full post body'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('news-post-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('news-post-post-a')), findsOneWidget);
  });

  testWidgets('video post uses adaptive stage and expandable overlay caption', (
    tester,
  ) async {
    final harness = await _pumpNewsApp(tester);
    addTearDown(harness.dispose);

    final videoCard = find.byKey(const ValueKey('news-post-video-a'));
    await tester.dragUntilVisible(
      videoCard,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    // The video card is taller than the 600 px test viewport. Move its
    // centre, not only its leading edge, into the tappable area.
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.tap(videoCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news-post-video-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-post-video-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-post-video-body')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('news-post-video-caption')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news-post-video-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-post-video-date')), findsOneWidget);
  });
}

NewsStory _story(
  String id,
  DateTime publishedAt, {
  bool isPinned = false,
  bool showOnHome = true,
}) {
  return NewsStory(
    id: id,
    title: LocalizedText(ru: id),
    body: const LocalizedText(ru: ''),
    badge: const LocalizedText(ru: ''),
    accentHex: 0xFFFF5A96,
    visual: NewsStoryVisual.sparkle,
    publishedAt: publishedAt.toIso8601String(),
    sortOrder: 0,
    isPinned: isPinned,
    showOnHome: showOnHome,
  );
}

Future<_NewsHarness> _pumpNewsApp(WidgetTester tester) async {
  final controller = _newsController(_MemoryStoryViewStore());
  await controller.bootstrap();
  final router = GoRouter(
    initialLocation: '/news',
    routes: [
      GoRoute(path: '/news', builder: (context, state) => const NewsPage()),
      GoRoute(
        path: '/news/collection/:id',
        builder: (context, state) =>
            NewsStoryPage(collectionId: state.pathParameters['id']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStateProvider.overrideWith((ref) => controller)],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: [
          for (final language in AppLanguage.values) language.locale,
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _NewsHarness(router, controller);
}

AppStateController _newsController(StoryViewStore storyViewStore) {
  return AppStateController(
    api: _NewsApi(),
    languagePreferences: _MemoryPreferences(),
    authStore: _MemoryAuthStore(),
    cartStore: _MemoryCartStore(),
    storyViewStore: storyViewStore,
  );
}

class _NewsHarness {
  const _NewsHarness(this.router, this.controller);

  final GoRouter router;
  final AppStateController controller;

  void dispose() {
    router.dispose();
  }
}

class _NewsApi extends ApiClient {
  _NewsApi({
    this.homeStories = const [],
    this.accentColor = AppColors.candy500,
  });

  final List<NewsStory> homeStories;
  final Color accentColor;

  final collectionStories = [
    for (var index = 0; index < 45; index++)
      _story(
        'collection-story-$index',
        DateTime.utc(2025, 1, 1).add(Duration(days: index)),
      ),
  ];

  @override
  Future<CompanyConfig?> fetchConfig() async => CompanyConfig(
    appName: 'SweetTime',
    accentColor: accentColor,
    earnRate: Loyalty.earnRate,
    maxSpendShare: Loyalty.maxSpendShare,
  );

  @override
  Future<List<Product>?> fetchProducts() async => DemoData.products;

  @override
  Future<List<Branch>?> fetchBranches() async => DemoData.branches;

  @override
  Future<List<Promotion>?> fetchPromotions() async => const [];

  @override
  Future<List<NewsStory>?> fetchHomeStories({int limit = 30}) async =>
      homeStories;

  @override
  Future<List<NewsStory>?> fetchNews() async => null;

  @override
  Future<List<StoryCollection>?> fetchStoryCollections() async => const [
    StoryCollection(
      id: 'large',
      name: LocalizedText(ru: 'Большая', ky: 'Чоң', en: 'Large collection'),
      sortOrder: 0,
    ),
  ];

  @override
  Future<List<NewsStory>?> fetchCollectionStories(String collectionId) async =>
      collectionId == 'large' ? collectionStories : const [];

  @override
  Future<List<NewsPost>?> fetchNewsPosts() async => const [
    NewsPost(
      id: 'post-a',
      title: LocalizedText(ru: 'Публикация', ky: 'Жарыя', en: 'Post title'),
      summary: LocalizedText(ru: 'Кратко', ky: 'Кыскача', en: 'Post summary'),
      body: LocalizedText(
        ru: 'Полный текст публикации',
        ky: 'Жарыянын толук тексти',
        en: 'Full post body',
      ),
      publishedAt: '2025-01-01T00:00:00Z',
    ),
    NewsPost(
      id: 'video-a',
      title: LocalizedText(
        ru: 'Видео публикация',
        ky: 'Видео жарыя',
        en: 'Video post',
      ),
      summary: LocalizedText(ru: '', ky: '', en: ''),
      body: LocalizedText(
        ru: 'Полный текст видео',
        ky: 'Видеонун толук тексти',
        en: 'Full video body',
      ),
      publishedAt: '2024-12-31T00:00:00Z',
      mediaType: NewsMediaType.video,
      mediaUrl: '',
    ),
  ];
}

class _MemoryPreferences implements LanguagePreferenceStore {
  @override
  Future<String?> readLanguageCode() async => 'en';

  @override
  Future<String?> readThemeMode() async => null;

  @override
  Future<void> writeLanguageCode(String code) async {}

  @override
  Future<void> writeThemeMode(String value) async {}

  @override
  Future<String?> readBackgroundOverride() async => null;

  @override
  Future<void> writeBackgroundOverride(String? value) async {}
}

class _MemoryAuthStore implements AuthStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

class _MemoryCartStore implements CartStore {
  @override
  Future<List<CartDraftItem>> read() async => const [];

  @override
  Future<void> write(List<CartDraftItem> items) async {}
}

class _MemoryStoryViewStore implements StoryViewStore {
  Set<String> ids = {};

  @override
  Future<Set<String>> readViewedStoryIds() async => Set.unmodifiable(ids);

  @override
  Future<void> writeViewedStoryIds(Set<String> ids) async {
    this.ids = Set.of(ids);
  }
}
