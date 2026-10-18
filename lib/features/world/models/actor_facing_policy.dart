abstract final class ActorFacingPolicy {
  /// Pawdo's current side-walk sprite sheets are authored facing left.
  static double horizontalScaleX(
    double directionX, {
    bool sourceFacesLeft = true,
  }) {
    if (!directionX.isFinite || directionX == 0) return 1;

    final movingLeft = directionX < 0;
    if (sourceFacesLeft) return movingLeft ? 1 : -1;
    return movingLeft ? -1 : 1;
  }
}
