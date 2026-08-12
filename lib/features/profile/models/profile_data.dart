import 'package:cloud_firestore/cloud_firestore.dart';

import '../../characters/models/character_appearance.dart';

enum ProfileTheme { rose, lavender, sunset }

class ProfileData {
  const ProfileData({
    required this.uid,
    required this.email,
    required this.name,
    required this.displayName,
    required this.birthday,
    required this.relationshipStartDate,
    required this.photoStoragePath,
    required this.coupleCode,
    required this.theme,
    this.characterAppearance = const CharacterAppearance(),
    this.revision = '',
  });

  factory ProfileData.fromMap(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    final displayName = data['displayName']?.toString().trim() ?? '';
    return ProfileData(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      name: name,
      displayName: displayName.isEmpty ? name : displayName,
      birthday: _readDate(data['birthday']),
      relationshipStartDate: _readDate(data['relationshipStartDate']),
      photoStoragePath: data['photoStoragePath']?.toString() ?? '',
      coupleCode: data['coupleCode']?.toString() ?? '',
      theme: ProfileTheme.values.firstWhere(
        (theme) => theme.name == data['profileTheme']?.toString(),
        orElse: () => ProfileTheme.rose,
      ),
      characterAppearance: CharacterAppearance.fromMap(
        data['characterAppearance'],
      ),
      revision:
          _readDate(data['updatedAt'])?.millisecondsSinceEpoch.toString() ?? '',
    );
  }

  final String uid;
  final String email;
  final String name;
  final String displayName;
  final DateTime? birthday;
  final DateTime? relationshipStartDate;
  final String photoStoragePath;
  final String coupleCode;
  final ProfileTheme theme;
  final CharacterAppearance characterAppearance;
  final String revision;

  String get greetingName {
    if (displayName.isNotEmpty) return displayName;
    if (name.isNotEmpty) return name;
    return 'Usuario Pawdo';
  }

  int daysTogether(DateTime now) {
    final start = relationshipStartDate;
    if (start == null) return 0;
    final startDay = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    if (startDay.isAfter(today)) return 0;
    return today.difference(startDay).inDays;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

String formatProfileDate(DateTime? date) {
  if (date == null) return 'Sin configurar';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
