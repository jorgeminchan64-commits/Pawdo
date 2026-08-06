class YoutubeHelper {
  static String? extractVideoId(String input) {
    final value = input.trim();

    if (value.isEmpty) return null;

    // Si pega solo el ID del video.
    final simpleIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (simpleIdRegex.hasMatch(value)) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    // https://youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return _cleanVideoId(id);
    }

    // https://www.youtube.com/watch?v=VIDEO_ID
    if (uri.host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null) return _cleanVideoId(videoId);

      // https://www.youtube.com/shorts/VIDEO_ID
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        return uri.pathSegments.length > 1
            ? _cleanVideoId(uri.pathSegments[1])
            : null;
      }

      // https://www.youtube.com/embed/VIDEO_ID
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
        return uri.pathSegments.length > 1
            ? _cleanVideoId(uri.pathSegments[1])
            : null;
      }
    }

    return null;
  }

  static String? _cleanVideoId(String? value) {
    if (value == null || value.isEmpty) return null;

    final clean = value.split('?').first.split('&').first.trim();

    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');

    if (!regex.hasMatch(clean)) return null;

    return clean;
  }
}
