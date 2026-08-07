class GameSnapshot {
  const GameSnapshot._();

  static List<String> strings(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  static List<String> fixedStrings(
    dynamic value, {
    required int length,
    Set<String>? allowed,
  }) {
    final source = value is List ? value : const <dynamic>[];
    return List<String>.generate(length, (index) {
      if (index >= source.length || source[index] is! String) return '';
      final item = source[index] as String;
      return allowed == null || allowed.contains(item) ? item : '';
    }, growable: false);
  }

  static List<int> indices(dynamic value, {required int upperBound}) {
    if (value is! List) return const <int>[];
    final result = <int>[];
    for (final item in value) {
      final index = item is num ? item.toInt() : -1;
      if (index >= 0 && index < upperBound && !result.contains(index)) {
        result.add(index);
      }
    }
    return List<int>.unmodifiable(result);
  }
}
