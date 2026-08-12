import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/memories/models/memory_entry.dart';
import 'package:pawdo/features/memories/services/memory_service.dart';

void main() {
  test('memory tags are normalized, deduplicated and bounded', () {
    final tags = MemoryService.normalizeTags([
      ' Viaje ',
      'viaje',
      'AMOR',
      '',
      'x' * 31,
      ...List.generate(12, (index) => 'tag$index'),
    ]);

    expect(tags.first, 'viaje');
    expect(tags, contains('amor'));
    expect(tags.length, 10);
    expect(tags.where((value) => value == 'viaje'), hasLength(1));
  });

  test('every album category has a user-facing label', () {
    for (final category in MemoryCategory.values) {
      final memory = MemoryEntry(
        id: 'memory',
        description: '',
        date: DateTime(2026),
        place: '',
        tags: const [],
        category: category,
        createdBy: '',
        favoriteBy: const {},
        originalPath: '',
        thumbnailPath: '',
      );
      expect(memory.categoryLabel, isNotEmpty);
    }
  });

  test('favorites belong independently to each partner', () {
    final memory = MemoryEntry(
      id: 'memory',
      description: 'Nuestra cita',
      date: DateTime(2026),
      place: 'Lima',
      tags: const ['amor'],
      category: MemoryCategory.date,
      createdBy: 'user-one',
      favoriteBy: const {'user-two'},
      originalPath: 'original.jpg',
      thumbnailPath: 'thumb.jpg',
    );

    expect(memory.isFavoriteFor('user-one'), isFalse);
    expect(memory.isFavoriteFor('user-two'), isTrue);
  });
}
