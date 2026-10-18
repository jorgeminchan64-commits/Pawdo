import 'dart:typed_data';
import 'dart:ui' as ui;

/// Pixel-accurate interaction mask for sprites with transparent padding.
///
/// The rendered sprite can be scaled independently from the source image. The
/// caller converts the world point to normalized sprite coordinates before
/// asking the mask whether that pixel is visible.
final class AlphaHitMask {
  AlphaHitMask._({
    required this.width,
    required this.height,
    required Uint8List alpha,
  }) : _alpha = alpha;

  final int width;
  final int height;
  final Uint8List _alpha;

  static const int defaultThreshold = 24;

  static Future<AlphaHitMask?> fromImage(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    return fromRgba(
      width: image.width,
      height: image.height,
      rgba: Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
    );
  }

  static AlphaHitMask fromRgba({
    required int width,
    required int height,
    required Uint8List rgba,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('The hit-mask dimensions must be positive.');
    }
    final expectedLength = width * height * 4;
    if (rgba.lengthInBytes != expectedLength) {
      throw ArgumentError.value(
        rgba.lengthInBytes,
        'rgba.lengthInBytes',
        'Expected $expectedLength RGBA bytes.',
      );
    }

    final alpha = Uint8List(width * height);
    for (var pixel = 0; pixel < alpha.length; pixel++) {
      alpha[pixel] = rgba[pixel * 4 + 3];
    }
    return AlphaHitMask._(width: width, height: height, alpha: alpha);
  }

  bool containsNormalized(
    double normalizedX,
    double normalizedY, {
    int threshold = defaultThreshold,
  }) {
    if (!normalizedX.isFinite || !normalizedY.isFinite) return false;
    if (normalizedX < 0 || normalizedX > 1) return false;
    if (normalizedY < 0 || normalizedY > 1) return false;

    final x = (normalizedX * (width - 1)).round().clamp(0, width - 1);
    final y = (normalizedY * (height - 1)).round().clamp(0, height - 1);
    return _alpha[y * width + x] >= threshold.clamp(0, 255);
  }
}
