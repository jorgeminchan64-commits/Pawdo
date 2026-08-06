class CinemaSource {
  final String platform;
  final String originalUrl;
  final String embedUrl;
  final String? videoId;
  final String title;

  const CinemaSource({
    required this.platform,
    required this.originalUrl,
    required this.embedUrl,
    required this.title,
    this.videoId,
  });

  bool get isYoutube => platform == 'youtube';
  bool get isWebView => platform != 'youtube';

  Map<String, dynamic> toJson({required String? updatedBy}) {
    return {
      'platform': platform,
      'originalUrl': originalUrl,
      'embedUrl': embedUrl,
      'videoId': videoId,
      'title': title,
      'updatedBy': updatedBy,
    };
  }
}

class CinemaLinkHelper {
  static CinemaSource? parse(String input) {
    final value = input.trim();

    if (value.isEmpty) return null;

    final youtube = _parseYoutube(value);
    if (youtube != null) return youtube;

    final okRu = _parseOkRu(value);
    if (okRu != null) return okRu;

    final drive = _parseGoogleDrive(value);
    if (drive != null) return drive;

    final web = _parseGenericWeb(value);
    if (web != null) return web;

    return null;
  }

  static CinemaSource? fromFirebase(Map<String, dynamic> data) {
    final platform = data['platform']?.toString();
    final originalUrl = data['originalUrl']?.toString();
    final embedUrl = data['embedUrl']?.toString();
    final videoId = data['videoId']?.toString();
    final title = data['title']?.toString();

    // Compatibilidad con tu versión anterior: solo guardaba videoId.
    if ((platform == null || platform.isEmpty) &&
        videoId != null &&
        videoId.isNotEmpty) {
      return CinemaSource(
        platform: 'youtube',
        originalUrl: 'https://www.youtube.com/watch?v=$videoId',
        embedUrl: 'https://www.youtube.com/watch?v=$videoId',
        videoId: videoId,
        title: 'YouTube',
      );
    }

    if (platform == null ||
        platform.isEmpty ||
        originalUrl == null ||
        originalUrl.isEmpty ||
        embedUrl == null ||
        embedUrl.isEmpty) {
      return null;
    }

    return CinemaSource(
      platform: platform,
      originalUrl: originalUrl,
      embedUrl: embedUrl,
      videoId: videoId,
      title: title ?? _titleForPlatform(platform),
    );
  }

  static CinemaSource? _parseYoutube(String value) {
    final videoId = _extractYoutubeId(value);

    if (videoId == null) return null;

    return CinemaSource(
      platform: 'youtube',
      originalUrl: 'https://www.youtube.com/watch?v=$videoId',
      embedUrl: 'https://www.youtube.com/watch?v=$videoId',
      videoId: videoId,
      title: 'YouTube',
    );
  }

  static String? _extractYoutubeId(String input) {
    final value = input.trim();

    final simpleIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (simpleIdRegex.hasMatch(value)) return value;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      if (uri.pathSegments.isEmpty) return null;
      return _cleanYoutubeId(uri.pathSegments.first);
    }

    if (uri.host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null) return _cleanYoutubeId(videoId);

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'shorts') {
        return _cleanYoutubeId(uri.pathSegments[1]);
      }

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'embed') {
        return _cleanYoutubeId(uri.pathSegments[1]);
      }
    }

    return null;
  }

  static String? _cleanYoutubeId(String? value) {
    if (value == null || value.isEmpty) return null;

    final clean = value.split('?').first.split('&').first.trim();
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');

    if (!regex.hasMatch(clean)) return null;

    return clean;
  }

  static CinemaSource? _parseOkRu(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (!uri.host.contains('ok.ru')) return null;

    String? videoId;

    final segments = uri.pathSegments;

    for (int i = 0; i < segments.length; i++) {
      if ((segments[i] == 'video' || segments[i] == 'videoembed') &&
          i + 1 < segments.length) {
        videoId = segments[i + 1];
        break;
      }
    }

    videoId ??= uri.queryParameters['st.mvId'];

    if (videoId == null || videoId.isEmpty) return null;

    final cleanId = videoId.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanId.isEmpty) return null;

    return CinemaSource(
      platform: 'okru',
      originalUrl: 'https://ok.ru/video/$cleanId',
      embedUrl: 'https://ok.ru/videoembed/$cleanId',
      videoId: cleanId,
      title: 'OK.ru',
    );
  }

  static CinemaSource? _parseGoogleDrive(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (!uri.host.contains('drive.google.com')) return null;

    String? fileId;

    final segments = uri.pathSegments;

    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == 'd' && i + 1 < segments.length) {
        fileId = segments[i + 1];
        break;
      }
    }

    fileId ??= uri.queryParameters['id'];

    if (fileId == null || fileId.isEmpty) return null;

    return CinemaSource(
      platform: 'drive',
      originalUrl: value,
      embedUrl: 'https://drive.google.com/file/d/$fileId/preview',
      videoId: fileId,
      title: 'Google Drive',
    );
  }

  static CinemaSource? _parseGenericWeb(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return CinemaSource(
      platform: 'web',
      originalUrl: value,
      embedUrl: value,
      title: uri.host,
    );
  }

  static String _titleForPlatform(String platform) {
    switch (platform) {
      case 'youtube':
        return 'YouTube';
      case 'okru':
        return 'OK.ru';
      case 'drive':
        return 'Google Drive';
      case 'web':
        return 'Web';
      default:
        return 'Video';
    }
  }
}
