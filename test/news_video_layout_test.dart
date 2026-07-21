import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/features/news/news_page.dart';

void main() {
  test('video stage follows native aspect ratio and safe screen height', () {
    expect(
      adaptiveNewsVideoHeight(
        availableWidth: 360,
        availableHeight: 760,
        videoAspectRatio: 9 / 16,
      ),
      closeTo(640, 0.001),
    );
    expect(
      adaptiveNewsVideoHeight(
        availableWidth: 360,
        availableHeight: 760,
        videoAspectRatio: 3 / 4,
      ),
      closeTo(480, 0.001),
    );
    expect(
      adaptiveNewsVideoHeight(
        availableWidth: 360,
        availableHeight: 760,
        videoAspectRatio: 16 / 9,
      ),
      closeTo(202.5, 0.001),
    );
    expect(
      adaptiveNewsVideoHeight(
        availableWidth: 360,
        availableHeight: 760,
        videoAspectRatio: 0.3,
      ),
      760,
    );
  });
}
