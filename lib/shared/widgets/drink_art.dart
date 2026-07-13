import 'package:flutter/material.dart';

import '../app_models.dart';

/// Заглушка-иллюстрация напитка (когда нет фото) — стакан бабл-ти в цвет продукта.
class DrinkArt extends StatelessWidget {
  const DrinkArt({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: size * 0.55,
            height: size * 0.85,
            child: CustomPaint(painter: _CupPainter(product.accentColor)),
          ),
        );
      },
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // корпус стакана — трапеция
    final cupPath = Path()
      ..moveTo(w * 0.12, h * 0.18)
      ..lineTo(w * 0.88, h * 0.18)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    canvas.drawPath(cupPath, Paint()..color = color.withValues(alpha: 0.35));

    // напиток
    final drinkPath = Path()
      ..moveTo(w * 0.16, h * 0.42)
      ..lineTo(w * 0.84, h * 0.42)
      ..lineTo(w * 0.76, h * 0.96)
      ..lineTo(w * 0.24, h * 0.96)
      ..close();
    canvas.drawPath(drinkPath, Paint()..color = color.withValues(alpha: 0.85));

    // крышка
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.14),
      Radius.circular(h * 0.06),
    );
    canvas.drawRRect(lid, Paint()..color = color.withValues(alpha: 0.6));

    // трубочка
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, -h * 0.02, w * 0.09, h * 0.32),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = color.withValues(alpha: 0.75),
    );

    // жемчужины тапиоки
    final pearl = Paint()
      ..color = const Color(0xFF3A2A2A).withValues(alpha: 0.55);
    final positions = [
      Offset(w * 0.34, h * 0.86),
      Offset(w * 0.5, h * 0.9),
      Offset(w * 0.66, h * 0.85),
      Offset(w * 0.42, h * 0.78),
      Offset(w * 0.58, h * 0.79),
    ];
    for (final p in positions) {
      canvas.drawCircle(p, w * 0.06, pearl);
    }
  }

  @override
  bool shouldRepaint(covariant _CupPainter oldDelegate) =>
      oldDelegate.color != color;
}
