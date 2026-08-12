import 'package:cloud_firestore/cloud_firestore.dart';

enum MemoryCategory { travel, date, anniversary, special, other }

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.description,
    required this.date,
    required this.place,
    required this.tags,
    required this.category,
    required this.createdBy,
    required this.favoriteBy,
    required this.originalPath,
    required this.thumbnailPath,
  });

  factory MemoryEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawTags = data['tags'];
    final rawFavorites = data['favoriteBy'];
    return MemoryEntry(
      id: document.id,
      description: data['description']?.toString() ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(1970),
      place: data['place']?.toString() ?? '',
      tags: rawTags is List
          ? rawTags.map((value) => value.toString()).toList(growable: false)
          : const [],
      category: MemoryCategory.values.firstWhere(
        (value) => value.name == data['category'],
        orElse: () => MemoryCategory.other,
      ),
      createdBy: data['createdBy']?.toString() ?? '',
      favoriteBy: rawFavorites is List
          ? rawFavorites.map((value) => value.toString()).toSet()
          : const {},
      originalPath: data['originalPath']?.toString() ?? '',
      thumbnailPath: data['thumbnailPath']?.toString() ?? '',
    );
  }

  final String id;
  final String description;
  final DateTime date;
  final String place;
  final List<String> tags;
  final MemoryCategory category;
  final String createdBy;
  final Set<String> favoriteBy;
  final String originalPath;
  final String thumbnailPath;

  bool isFavoriteFor(String uid) => favoriteBy.contains(uid);

  String get categoryLabel => switch (category) {
    MemoryCategory.travel => 'Viajes',
    MemoryCategory.date => 'Citas',
    MemoryCategory.anniversary => 'Aniversarios',
    MemoryCategory.special => 'Momentos especiales',
    MemoryCategory.other => 'Otros',
  };
}
