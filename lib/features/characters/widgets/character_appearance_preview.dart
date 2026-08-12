import 'package:flutter/material.dart';

import '../models/character_appearance.dart';

class CharacterAppearancePreview extends StatelessWidget {
  const CharacterAppearancePreview({
    super.key,
    required this.appearance,
    this.size = 230,
  });

  final CharacterAppearance appearance;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista previa del personaje personalizado',
      image: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDF5), Color(0xFFF0E8FB)],
          ),
          borderRadius: BorderRadius.circular(size * .16),
        ),
        child: CustomPaint(painter: _CharacterPainter(appearance)),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter(this.appearance);

  final CharacterAppearance appearance;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 230;
    canvas.save();
    canvas.scale(scale);

    final skin = Paint()..color = _skinColor(appearance.skinTone);
    final hair = Paint()..color = _hairColor(appearance.hairColor);
    final outfit = Paint()..color = _outfitColor(appearance.outfitColor);
    final dark = Paint()..color = const Color(0xFF342A37);
    final shoe = Paint()
      ..color = appearance.shoes == CharacterShoes.boots
          ? const Color(0xFF5D3C32)
          : const Color(0xFFF8F5F6);

    final headCenter = const Offset(115, 64);
    canvas.drawCircle(headCenter, 31, skin);
    _paintHair(canvas, hair);
    _paintFace(canvas, dark, skin);

    final body = switch (appearance.outfitStyle) {
      CharacterOutfitStyle.casual => RRect.fromRectAndRadius(
        const Rect.fromLTWH(78, 94, 74, 76),
        const Radius.circular(22),
      ),
      CharacterOutfitStyle.cozy => RRect.fromRectAndRadius(
        const Rect.fromLTWH(73, 92, 84, 82),
        const Radius.circular(28),
      ),
      CharacterOutfitStyle.elegant => RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 92, 66, 86),
        const Radius.circular(14),
      ),
    };
    canvas.drawRRect(body, outfit);

    final armY = appearance.pose == CharacterPose.sit ? 128.0 : 112.0;
    final leftHand = appearance.pose == CharacterPose.wave
        ? const Offset(66, 75)
        : Offset(68, armY + 34);
    canvas.drawLine(const Offset(84, 112), leftHand, _limbPaint(skin.color));
    canvas.drawLine(
      const Offset(146, 112),
      Offset(162, armY + 34),
      _limbPaint(skin.color),
    );

    if (appearance.pose == CharacterPose.sit) {
      canvas.drawLine(
        const Offset(99, 166),
        const Offset(82, 191),
        _limbPaint(outfit.color),
      );
      canvas.drawLine(
        const Offset(131, 166),
        const Offset(148, 191),
        _limbPaint(outfit.color),
      );
      canvas.drawOval(const Rect.fromLTWH(67, 187, 30, 13), shoe);
      canvas.drawOval(const Rect.fromLTWH(133, 187, 30, 13), shoe);
    } else {
      canvas.drawLine(
        const Offset(101, 166),
        const Offset(96, 205),
        _limbPaint(outfit.color),
      );
      canvas.drawLine(
        const Offset(129, 166),
        const Offset(134, 205),
        _limbPaint(outfit.color),
      );
      canvas.drawOval(const Rect.fromLTWH(80, 199, 30, 13), shoe);
      canvas.drawOval(const Rect.fromLTWH(120, 199, 30, 13), shoe);
    }

    _paintAccessory(canvas, dark);
    canvas.restore();
  }

  Paint _limbPaint(Color color) => Paint()
    ..color = color
    ..strokeWidth = 15
    ..strokeCap = StrokeCap.round;

  void _paintHair(Canvas canvas, Paint hair) {
    switch (appearance.hairStyle) {
      case CharacterHairStyle.short:
        canvas.drawArc(
          const Rect.fromLTWH(83, 30, 64, 58),
          3.1,
          3.2,
          true,
          hair,
        );
      case CharacterHairStyle.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(78, 29, 74, 86),
            const Radius.circular(34),
          ),
          hair,
        );
        canvas.drawCircle(
          const Offset(115, 65),
          29,
          Paint()..color = _skinColor(appearance.skinTone),
        );
      case CharacterHairStyle.curls:
        for (final center in const <Offset>[
          Offset(88, 48),
          Offset(101, 35),
          Offset(117, 32),
          Offset(133, 37),
          Offset(143, 50),
          Offset(84, 64),
          Offset(146, 66),
        ]) {
          canvas.drawCircle(center, 13, hair);
        }
    }
  }

  void _paintFace(Canvas canvas, Paint dark, Paint skin) {
    final eyeY = appearance.expression == CharacterExpression.excited
        ? 59.0
        : 61.0;
    canvas.drawCircle(Offset(104, eyeY), 2.8, dark);
    canvas.drawCircle(Offset(126, eyeY), 2.8, dark);
    final mouth = Path()..moveTo(106, 74);
    switch (appearance.expression) {
      case CharacterExpression.smile:
        mouth.quadraticBezierTo(115, 82, 124, 74);
      case CharacterExpression.calm:
        mouth.lineTo(124, 74);
      case CharacterExpression.excited:
        canvas.drawOval(
          const Rect.fromLTWH(108, 71, 14, 11),
          Paint()..color = const Color(0xFF8F2949),
        );
        return;
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF8F2949)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintAccessory(Canvas canvas, Paint dark) {
    switch (appearance.accessory) {
      case CharacterAccessory.none:
        return;
      case CharacterAccessory.glasses:
        final line = Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(const Offset(103, 61), 8, line);
        canvas.drawCircle(const Offset(127, 61), 8, line);
        canvas.drawLine(const Offset(111, 61), const Offset(119, 61), line);
      case CharacterAccessory.heartPin:
        canvas.drawCircle(
          const Offset(137, 111),
          6,
          Paint()..color = const Color(0xFFE75A8C),
        );
      case CharacterAccessory.headband:
        canvas.drawArc(
          const Rect.fromLTWH(87, 32, 56, 38),
          3.2,
          3.0,
          false,
          Paint()
            ..color = const Color(0xFFE75A8C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) {
    return oldDelegate.appearance.toMap().toString() !=
        appearance.toMap().toString();
  }
}

Color _skinColor(CharacterSkinTone value) => switch (value) {
  CharacterSkinTone.light => const Color(0xFFF6D1BB),
  CharacterSkinTone.warm => const Color(0xFFD99A72),
  CharacterSkinTone.deep => const Color(0xFF8C5A43),
};

Color _hairColor(CharacterHairColor value) => switch (value) {
  CharacterHairColor.brown => const Color(0xFF6C4333),
  CharacterHairColor.black => const Color(0xFF29242A),
  CharacterHairColor.blonde => const Color(0xFFD9B35F),
  CharacterHairColor.copper => const Color(0xFFB65E3C),
};

Color _outfitColor(CharacterOutfitColor value) => switch (value) {
  CharacterOutfitColor.rose => const Color(0xFFE75A8C),
  CharacterOutfitColor.plum => const Color(0xFF743B83),
  CharacterOutfitColor.blue => const Color(0xFF4F79B7),
  CharacterOutfitColor.green => const Color(0xFF4F8C72),
};
