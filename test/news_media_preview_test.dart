import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/features/news/news_media.dart';
import 'package:sweettime/shared/app_models.dart';

void main() {
  testWidgets('inactive video preview never paints a play overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: NewsMediaView(
              mediaType: NewsMediaType.video,
              url: 'https://example.invalid/story.mp4',
              allowVideo: false,
              fallbackIcon: Icons.storefront_outlined,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });
}
