import 'dart:ui';

abstract final class GardenLayoutPolicy {
  static const Rect placementBounds = Rect.fromLTRB(120, 120, 1680, 820);

  /// Areas occupied by the legacy edit control and right-side navigation.
  static const List<Rect> reservedUiZones = <Rect>[
    Rect.fromLTWH(0, 720, 300, 180),
    Rect.fromLTWH(1500, 0, 300, 900),
  ];

  static Offset clampCenter(Offset candidate, Size visualSize) {
    if (!_validSize(visualSize)) {
      throw ArgumentError.value(visualSize, 'visualSize');
    }

    final safeX = candidate.dx.isFinite
        ? candidate.dx
        : placementBounds.center.dx;
    final safeY = candidate.dy.isFinite
        ? candidate.dy
        : placementBounds.center.dy;
    final halfWidth = visualSize.width / 2;
    final halfHeight = visualSize.height / 2;
    final minX = placementBounds.left + halfWidth;
    final maxX = placementBounds.right - halfWidth;
    final minY = placementBounds.top + halfHeight;
    final maxY = placementBounds.bottom - halfHeight;

    if (minX > maxX || minY > maxY) {
      throw ArgumentError.value(
        visualSize,
        'visualSize',
        'The item does not fit inside the garden placement bounds.',
      );
    }

    return Offset(
      safeX.clamp(minX, maxX).toDouble(),
      safeY.clamp(minY, maxY).toDouble(),
    );
  }

  static Rect visualBounds(Offset center, Size visualSize) {
    return Rect.fromCenter(
      center: center,
      width: visualSize.width,
      height: visualSize.height,
    );
  }

  static bool isInsideSafeArea(Offset center, Size visualSize) {
    if (!_validSize(visualSize) || !center.dx.isFinite || !center.dy.isFinite) {
      return false;
    }
    final bounds = visualBounds(center, visualSize);
    if (bounds.left < placementBounds.left ||
        bounds.top < placementBounds.top ||
        bounds.right > placementBounds.right ||
        bounds.bottom > placementBounds.bottom) {
      return false;
    }
    return !reservedUiZones.any(bounds.overlaps);
  }

  static bool _validSize(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }
}
