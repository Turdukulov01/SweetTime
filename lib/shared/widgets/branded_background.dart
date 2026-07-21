import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';

class BrandedBackground extends ConsumerWidget {
  const BrandedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      appStateProvider.select(
        (state) => (
          background: state.backgroundTheme,
          override: state.backgroundOverride,
        ),
      ),
    );
    final background = data.background;
    final override = data.override;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // База (сплошная заливка) всегда берётся из брендовой темы админки, даже
    // если юзер выбрал свой узор — так фон остаётся в фирменных цветах.
    final base = dark ? background.darkBase : background.lightBase;

    // Личный выбор перекрывает админский (см. AppState.backgroundOverride).
    final String kind;
    final String preset;
    final String? image;
    switch (override) {
      case null: // «как в приложении» — следуем за админкой
        kind = background.kind;
        preset = background.preset;
        image = background.kind == 'image' ? background.imageUrl : null;
      case 'off': // фон выключен — только базовая заливка
        kind = 'plain';
        preset = 'none';
        image = null;
      default: // свой узор ('plain' — без узора, только заливка)
        kind = 'pattern';
        preset = override;
        image = null;
    }

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null && image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else if (kind == 'pattern' && preset != 'none')
            CustomPaint(
              painter: _BrandPatternPainter(
                preset: preset,
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: background.patternOpacity,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _BrandPatternPainter extends CustomPainter {
  const _BrandPatternPainter({required this.preset, required this.color});

  final String preset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const spacing = 72.0;
    for (double y = 20; y < size.height + spacing; y += spacing) {
      for (double x = 20; x < size.width + spacing; x += spacing) {
        final offset = Offset(x + ((y ~/ spacing).isOdd ? 28 : 0), y);
        switch (preset) {
          case 'bubbles':
            canvas.drawCircle(offset, 10, paint);
            canvas.drawCircle(offset + const Offset(13, 9), 5, paint);
            break;
          case 'coffee':
            canvas.drawOval(
              Rect.fromCenter(center: offset, width: 17, height: 25),
              paint,
            );
            canvas.drawLine(
              offset + const Offset(-5, 8),
              offset + const Offset(5, -8),
              paint,
            );
            break;
          default:
            canvas.drawCircle(offset, 8, paint);
            canvas.drawLine(
              offset + const Offset(-12, 0),
              offset + const Offset(12, 0),
              paint,
            );
            canvas.drawLine(
              offset + const Offset(0, -12),
              offset + const Offset(0, 12),
              paint,
            );
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrandPatternPainter oldDelegate) =>
      oldDelegate.preset != preset || oldDelegate.color != color;
}
