abstract final class InteriorInteractionPolicy {
  /// The legacy sleep frames contain baked-in props and cannot align both
  /// people with the same mattress. Keep this off until the 3D socket-based
  /// interaction replaces it.
  static const bool allowsLegacyBedInteraction = false;
}
