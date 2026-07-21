import 'package:flutter/material.dart';

/// Открывает изображение на весь экран поверх всего: плавно (Hero) вырастает
/// из миниатюры, зумится щипком (InteractiveViewer), закрывается тапом по фону,
/// крестиком или системной кнопкой «Назад».
///
/// [imageProvider] — сеть/asset/файл; если его нет (напр. логотип по умолчанию —
/// иконка, а не картинка), показывается [fallback]. [heroTag] совпадает с тем,
/// что обёрнут вокруг источника, чтобы полёт был непрерывным. [fallback] также
/// показывается, если картинка не загрузилась.
Future<void> showFullscreenImage(
  BuildContext context, {
  ImageProvider? imageProvider,
  Object? heroTag,
  Widget? fallback,
}) {
  assert(
    imageProvider != null || fallback != null,
    'Нужен либо imageProvider, либо fallback — иначе показывать нечего.',
  );
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _FullscreenImageView(
            imageProvider: imageProvider,
            heroTag: heroTag,
            fallback: fallback,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    ),
  );
}

class _FullscreenImageView extends StatelessWidget {
  const _FullscreenImageView({
    required this.imageProvider,
    required this.heroTag,
    this.fallback,
  });

  final ImageProvider? imageProvider;
  final Object? heroTag;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;
    final content = provider == null
        ? (fallback ?? const SizedBox.shrink())
        : Image(
            image: provider,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                fallback ?? const SizedBox.shrink(),
          );
    final viewer = InteractiveViewer(minScale: 1, maxScale: 4, child: content);
    final tag = heroTag;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Тап по фону закрывает; тап по самой картинке — нет (её жестами
          // двигают/зумят), поэтому GestureDetector стоит только на подложке.
          Positioned.fill(
            child: GestureDetector(
              onTap: Navigator.of(context).pop,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Center(
            child: tag == null ? viewer : Hero(tag: tag, child: viewer),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filled(
                  key: const ValueKey('fullscreen-image-close'),
                  onPressed: Navigator.of(context).pop,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
