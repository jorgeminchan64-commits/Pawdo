import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';
import '../services/cinema_link_helper.dart';

class PawdoCinemaScreen extends StatefulWidget {
  const PawdoCinemaScreen({super.key});

  @override
  State<PawdoCinemaScreen> createState() => _PawdoCinemaScreenState();
}

class _PawdoCinemaScreenState extends State<PawdoCinemaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  late final YoutubePlayerController _youtubeController;
  late final WebViewController _webViewController;
  late final Future<String?> _coupleCodeFuture;

  String? _loadedSourceKey;
  String? _cachedUserName;

  bool _isSaving = false;
  bool _isOpeningOutside = false;
  bool _webLoading = false;
  bool _isSendingMessage = false;
  bool _isSendingReaction = false;
  String? _lastAppliedPlaybackActionId;
  bool _isSavingPlayback = false;
  bool _isApplyingRemotePlayback = false;

  @override
  void initState() {
    super.initState();

    _coupleCodeFuture = _getCoupleCode();

    _youtubeController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
      ),
    );

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _webLoading = true);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _webLoading = false);
          },
        ),
      );
  }

  @override
  void dispose() {
    _linkController.dispose();
    _chatController.dispose();
    _youtubeController.close();
    super.dispose();
  }

  Future<String?> _getCoupleCode() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    return userDoc.data()?['coupleCode']?.toString();
  }

  Future<String> _getUserName() async {
    if (_cachedUserName != null) return _cachedUserName!;

    final user = _auth.currentUser;

    if (user == null) {
      _cachedUserName = 'Pawdo';
      return _cachedUserName!;
    }

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? {};

      final name = data['name']?.toString();

      if (name != null && name.trim().isNotEmpty) {
        _cachedUserName = name.trim();
      } else {
        _cachedUserName = user.email ?? 'Usuario Pawdo';
      }
    } catch (_) {
      _cachedUserName = user.email ?? 'Usuario Pawdo';
    }

    return _cachedUserName!;
  }

  Future<void> _syncSource(CinemaSource source) async {
    final sourceKey = '${source.platform}_${source.embedUrl}';

    if (_loadedSourceKey == sourceKey) return;

    _loadedSourceKey = sourceKey;

    if (source.isYoutube && source.videoId != null) {
      await _youtubeController.loadVideoById(videoId: source.videoId!);
      return;
    }

    setState(() => _webLoading = true);

    await _webViewController.loadRequest(Uri.parse(source.embedUrl));
  }

  String _sourceKey(CinemaSource source) {
    return '${source.platform}_${source.embedUrl}';
  }

  Map<String, dynamic> _cinemaPlaybackData(Map<String, dynamic> data) {
    final raw = data['cinemaPlayback'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  double _toDouble(dynamic value, double defaultValue) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  String _formatSeconds(double seconds) {
    final total = seconds.floor();
    final minutes = total ~/ 60;
    final rest = total % 60;

    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _savePlaybackCommand({
    required String coupleCode,
    required CinemaSource source,
    required bool isPlaying,
  }) async {
    if (_isSavingPlayback) return;

    if (!source.isYoutube || source.videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La sincronización exacta solo está disponible para YouTube.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSavingPlayback = true);

    try {
      final user = _auth.currentUser;
      final userName = await _getUserName();

      final seconds = await _youtubeController.currentTime;
      final actionId = DateTime.now().millisecondsSinceEpoch.toString();

      await _db.collection('couples').doc(coupleCode).set({
        'cinemaPlayback': {
          'sourceKey': _sourceKey(source),
          'platform': source.platform,
          'videoId': source.videoId,
          'isPlaying': isPlaying,
          'positionSeconds': seconds,
          'updatedBy': user?.uid,
          'updatedByName': userName,
          'updatedAt': FieldValue.serverTimestamp(),
          'actionId': actionId,
        },
        'lastAction': isPlaying
            ? 'Dieron play juntos en Cine Pawdo ▶️'
            : 'Pausaron juntos en Cine Pawdo ⏸️',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (isPlaying) {
        await _youtubeController.playVideo();
      } else {
        await _youtubeController.pauseVideo();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo sincronizar el cine. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPlayback = false);
    }
  }

  Future<void> _syncCurrentYoutubePosition({
    required String coupleCode,
    required CinemaSource source,
  }) async {
    if (_isSavingPlayback) return;

    if (!source.isYoutube || source.videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La sincronización exacta solo está disponible para YouTube.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSavingPlayback = true);

    try {
      final user = _auth.currentUser;
      final userName = await _getUserName();

      final seconds = await _youtubeController.currentTime;
      final stateText = (await _youtubeController.playerState)
          .toString()
          .toLowerCase();
      final isPlaying = stateText.contains('playing');

      final actionId = DateTime.now().millisecondsSinceEpoch.toString();

      await _db.collection('couples').doc(coupleCode).set({
        'cinemaPlayback': {
          'sourceKey': _sourceKey(source),
          'platform': source.platform,
          'videoId': source.videoId,
          'isPlaying': isPlaying,
          'positionSeconds': seconds,
          'updatedBy': user?.uid,
          'updatedByName': userName,
          'updatedAt': FieldValue.serverTimestamp(),
          'actionId': actionId,
        },
        'lastAction':
            'Sincronizaron Cine Pawdo en ${_formatSeconds(seconds)} ⏱️',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cine sincronizado en ${_formatSeconds(seconds)} ✅'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo sincronizar el segundo actual.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPlayback = false);
    }
  }

  Future<void> _applyRemotePlayback(
    CinemaSource source,
    Map<String, dynamic> playback,
  ) async {
    if (_isApplyingRemotePlayback) return;
    if (!source.isYoutube || source.videoId == null) return;

    final actionId = playback['actionId']?.toString();
    if (actionId == null || actionId.isEmpty) return;

    if (_lastAppliedPlaybackActionId == actionId) return;

    final playbackSourceKey = playback['sourceKey']?.toString();
    if (playbackSourceKey != _sourceKey(source)) return;

    _lastAppliedPlaybackActionId = actionId;
    _isApplyingRemotePlayback = true;

    try {
      final isPlaying = playback['isPlaying'] == true;
      final savedSeconds = _toDouble(playback['positionSeconds'], 0.0);

      double targetSeconds = savedSeconds;

      final updatedAt = playback['updatedAt'];

      if (isPlaying && updatedAt is Timestamp) {
        final elapsed = DateTime.now().difference(updatedAt.toDate()).inSeconds;
        targetSeconds += elapsed;
      }

      final currentSeconds = await _youtubeController.currentTime;
      final difference = (currentSeconds - targetSeconds).abs();

      if (difference > 3) {
        await _youtubeController.seekTo(
          seconds: targetSeconds,
          allowSeekAhead: true,
        );
      }

      if (isPlaying) {
        await _youtubeController.playVideo();
      } else {
        await _youtubeController.pauseVideo();
      }
    } catch (_) {
      // No mostramos error aquí para no molestar al usuario con sincronizaciones internas.
    } finally {
      _isApplyingRemotePlayback = false;
    }
  }

  Future<void> _saveVideoToFirebase(String coupleCode) async {
    if (_isSaving) return;

    final source = CinemaLinkHelper.parse(_linkController.text);

    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pega un link válido de YouTube, OK.ru, Drive o web.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;

      await _db.collection('couples').doc(coupleCode).set({
        'cinema': {
          ...source.toJson(updatedBy: user?.uid),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'lastAction': 'Abrieron Cine Pawdo 🎬',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _linkController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${source.title} cargado en Cine Pawdo 🎬')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el video. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openOutside(CinemaSource source) async {
    if (_isOpeningOutside) return;

    setState(() => _isOpeningOutside = true);

    final uri = Uri.parse(source.originalUrl);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    } finally {
      if (mounted) setState(() => _isOpeningOutside = false);
    }
  }

  Future<void> _sendReaction({
    required String coupleCode,
    required String emoji,
  }) async {
    if (_isSendingReaction) return;

    setState(() => _isSendingReaction = true);

    try {
      final user = _auth.currentUser;
      final userName = await _getUserName();

      await _db
          .collection('couples')
          .doc(coupleCode)
          .collection('cinemaReactions')
          .add({
            'emoji': emoji,
            'senderId': user?.uid,
            'senderName': userName,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la reacción.')),
      );
    } finally {
      if (mounted) setState(() => _isSendingReaction = false);
    }
  }

  Future<void> _sendChatMessage({
    required String coupleCode,
    String? forcedText,
  }) async {
    if (_isSendingMessage) return;

    final text = forcedText ?? _chatController.text.trim();

    if (text.isEmpty) return;

    setState(() => _isSendingMessage = true);

    try {
      final user = _auth.currentUser;
      final userName = await _getUserName();

      await _db
          .collection('couples')
          .doc(coupleCode)
          .collection('cinemaMessages')
          .add({
            'text': text,
            'senderId': user?.uid,
            'senderName': userName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (forcedText == null) {
        _chatController.clear();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje.')),
      );
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Map<String, dynamic> _cinemaData(Map<String, dynamic> data) {
    final raw = data['cinema'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'ahora';

    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, codeSnapshot) {
        final coupleCode = codeSnapshot.data;

        if (codeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF120B22),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (coupleCode == null || coupleCode.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF120B22),
            body: Center(
              child: Text(
                'Primero necesitas estar vinculado con tu pareja.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('couples').doc(coupleCode).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final cinema = _cinemaData(data);
            final playback = _cinemaPlaybackData(data);
            final source = CinemaLinkHelper.fromFirebase(cinema);

            if (source != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _syncSource(source);
                _applyRemotePlayback(source, playback);
              });
            }
            return Scaffold(
              backgroundColor: const Color(0xFF120B22),
              body: SafeArea(
                child: Column(
                  children: [
                    _topBar(context),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _cinemaHeader(),
                          const SizedBox(height: 16),
                          _videoCard(source),
                          const SizedBox(height: 12),
                          if (source != null) _fallbackCard(source),
                          const SizedBox(height: 12),
                          _syncControlPanel(
                            coupleCode: coupleCode,
                            source: source,
                            playback: playback,
                          ),
                          const SizedBox(height: 14),
                          _reactionBar(coupleCode),
                          const SizedBox(height: 12),
                          _liveReactions(coupleCode),
                          const SizedBox(height: 16),
                          _chatPanel(coupleCode),
                          const SizedBox(height: 16),
                          _linkBox(coupleCode),
                          const SizedBox(height: 14),
                          _supportedPlatformsBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Volver',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cine Pawdo 🎬',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cinemaHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2FFF), Color(0xFFFF5EA8)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Text('🍿', style: TextStyle(fontSize: 42)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Miren juntos videos de YouTube, OK.ru, Drive o web compatible.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoCard(CinemaSource? source) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: source == null
            ? Container(
                height: 260,
                color: const Color(0xFF1D1430),
                child: const Center(
                  child: Text(
                    'Todavía no hay video cargado 🎬',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : source.isYoutube
            ? YoutubePlayer(controller: _youtubeController, aspectRatio: 16 / 9)
            : SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    WebViewWidget(controller: _webViewController),
                    if (_webLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _fallbackCard(CinemaSource source) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🎥', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plataforma: ${source.title}. Si no carga dentro de Pawdo, ábrelo afuera.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isOpeningOutside ? null : () => _openOutside(source),
              icon: const Icon(Icons.open_in_new),
              label: Text(_isOpeningOutside ? 'Abriendo...' : 'Abrir afuera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncControlPanel({
    required String coupleCode,
    required CinemaSource? source,
    required Map<String, dynamic> playback,
  }) {
    if (source == null) {
      return const SizedBox.shrink();
    }

    if (!source.isYoutube) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Text('ℹ️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'La sincronización play/pausa/segundo funciona nivel PRO con YouTube. '
                'En ${source.title}, Pawdo comparte el mismo enlace, pero el reproductor puede no dejar controlar el segundo.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isSameSource =
        playback['sourceKey']?.toString() == _sourceKey(source);
    final isPlaying = isSameSource && playback['isPlaying'] == true;
    final double seconds = isSameSource
        ? _toDouble(playback['positionSeconds'], 0.0)
        : 0.0;
    final updatedByName = playback['updatedByName']?.toString() ?? 'Pawdo';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sincronización PRO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSameSource
                ? '${isPlaying ? "▶️ Reproduciendo" : "⏸️ Pausado"} · ${_formatSeconds(seconds)} · por $updatedByName'
                : 'Aún no hay sincronización para este video.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingPlayback
                      ? null
                      : () => _savePlaybackCommand(
                          coupleCode: coupleCode,
                          source: source,
                          isPlaying: true,
                        ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play juntos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingPlayback
                      ? null
                      : () => _savePlaybackCommand(
                          coupleCode: coupleCode,
                          source: source,
                          isPlaying: false,
                        ),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pausa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSavingPlayback
                  ? null
                  : () => _syncCurrentYoutubePosition(
                      coupleCode: coupleCode,
                      source: source,
                    ),
              icon: const Icon(Icons.sync),
              label: Text(
                _isSavingPlayback
                    ? 'Sincronizando...'
                    : 'Sincronizar segundo actual',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionBar(String coupleCode) {
    final reactions = ['❤️', '😂', '🐶', '🍿', '😍', '😭'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reacciones en vivo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reactions.map((emoji) {
                    return Material(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            _sendReaction(coupleCode: coupleCode, emoji: emoji),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _sendChatMessage(
                  coupleCode: coupleCode,
                  forcedText: 'Estoy viendo contigo 🍿',
                ),
                icon: const Icon(Icons.visibility),
                label: const Text('Estoy viendo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveReactions(String coupleCode) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('couples')
          .doc(coupleCode)
          .collection('cinemaReactions')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final emoji = data['emoji']?.toString() ?? '❤️';
              final sender = data['senderName']?.toString() ?? 'Pawdo';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(
                      sender,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _chatPanel(String coupleCode) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mini chat del cine 💬',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          _chatMessages(coupleCode),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Escribe algo mientras ven...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.pinkAccent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _isSendingMessage
                      ? null
                      : () => _sendChatMessage(coupleCode: coupleCode),
                  child: const Padding(
                    padding: EdgeInsets.all(13),
                    child: Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatMessages(String coupleCode) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('couples')
          .doc(coupleCode)
          .collection('cinemaMessages')
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Aún no hay mensajes en el cine 🍿',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return Container(
          height: 210,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.builder(
            reverse: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final senderId = data['senderId']?.toString();
              final senderName = data['senderName']?.toString() ?? 'Pawdo';
              final text = data['text']?.toString() ?? '';
              final createdAt = data['createdAt'];

              final mine = senderId == _auth.currentUser?.uid;

              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: mine
                        ? Colors.pinkAccent.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!mine)
                        Text(
                          senderName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _linkBox(String coupleCode) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cargar video',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _linkController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'YouTube, OK.ru, Drive o link web',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              prefixIcon: const Icon(Icons.link, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveVideoToFirebase(coupleCode),
              icon: const Icon(Icons.play_circle),
              label: Text(_isSaving ? 'Cargando...' : 'Cargar en Cine Pawdo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportedPlatformsBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'Cine V4: video compartido, reacciones en vivo, mini chat y sincronización YouTube. '
        'Pawdo guarda el mismo enlace para ambos. Si una plataforma bloquea el reproductor interno, ambos pueden abrir el mismo enlace afuera.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}
