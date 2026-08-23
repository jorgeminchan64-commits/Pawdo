import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../world/components/actors/animated_actor_component.dart';
import '../models/character_appearance.dart';

/// Shows the exact layered 2.5D actor used by the garden and the house.
/// Keeping this renderer shared prevents a choice looking different after the
/// user saves the character.
class CharacterAppearancePreview extends StatefulWidget {
  const CharacterAppearancePreview({
    super.key,
    required this.appearance,
    this.size = 230,
  });

  final CharacterAppearance appearance;
  final double size;

  @override
  State<CharacterAppearancePreview> createState() =>
      _CharacterAppearancePreviewState();
}

class _CharacterAppearancePreviewState
    extends State<CharacterAppearancePreview> {
  List<ui.Image>? _images;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadActorImages();
  }

  @override
  void didUpdateWidget(covariant CharacterAppearancePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance.baseStyle != widget.appearance.baseStyle) {
      _loadActorImages();
    }
  }

  Future<void> _loadActorImages() async {
    final generation = ++_loadGeneration;
    final isGirl =
        widget.appearance.baseStyle == CharacterBaseStyle.classicGirl;
    final prefix = isGirl ? 'avatar_girl' : 'avatar_boy';
    final images = await Future.wait([
      _loadImage('assets/images/avatars/${prefix}_pro_spritesheet.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_hair.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_skin.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_outfit.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_shoes.png'),
    ]);
    if (!mounted || generation != _loadGeneration) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    final previous = _images;
    setState(() => _images = images);
    if (previous != null) {
      for (final image in previous) {
        image.dispose();
      }
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  AnimatedActorComponent? _createActor() {
    final images = _images;
    if (images == null) return null;
    final isGirl =
        widget.appearance.baseStyle == CharacterBaseStyle.classicGirl;
    final actor = AnimatedActorComponent(
      spriteSheet: images[0],
      startPosition: Vector2.zero(),
      size: Vector2(150, 265),
      spriteLayout: isGirl ? ActorSpriteLayout.girl : ActorSpriteLayout.boy,
      appearanceLayers: ActorAppearanceLayers(
        appearance: widget.appearance,
        hairMask: images[1],
        skinMask: images[2],
        outfitMask: images[3],
        shoesMask: images[4],
      ),
    )..update(0);
    switch (widget.appearance.pose) {
      case CharacterPose.idle:
        break;
      case CharacterPose.wave:
        actor.wave();
      case CharacterPose.sit:
        actor.sit();
    }
    return actor;
  }

  @override
  Widget build(BuildContext context) {
    final actor = _createActor();
    return Semantics(
      label: 'Vista previa 2.5D del personaje personalizado',
      image: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDF5), Color(0xFFF0E8FB)],
          ),
          borderRadius: BorderRadius.circular(widget.size * .16),
          border: Border.all(color: const Color(0x24FFFFFF), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F6E3C70),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _PreviewBackdrop(),
            if (actor == null)
              const Center(
                child: SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              CustomPaint(
                key: ValueKey(widget.appearance.toMap().toString()),
                painter: _ActorPreviewPainter(actor),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    final images = _images;
    if (images != null) {
      for (final image in images) {
        image.dispose();
      }
    }
    super.dispose();
  }
}

class _PreviewBackdrop extends StatelessWidget {
  const _PreviewBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PreviewBackdropPainter());
  }
}

class _PreviewBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x8AFFFFFF), Color(0x00FFFFFF)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .5, size.height * .42),
              radius: size.width * .48,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .42),
      size.width * .48,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActorPreviewPainter extends CustomPainter {
  const _ActorPreviewPainter(this.actor);

  final AnimatedActorComponent actor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate((size.width - actor.size.x) / 2, size.height * .06);
    actor.render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActorPreviewPainter oldDelegate) => true;
}
