import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/app_providers.dart';
import '../../media/services/shared_media_service.dart';
import '../../settings/screens/notification_preferences_screen.dart';
import '../services/chat_service.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo cargar tu perfil.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final code = snapshot.data?.data()?['coupleCode']?.toString() ?? '';
        if (code.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Conecta a tu pareja para chatear.')),
          );
        }
        return _CoupleChat(key: ValueKey(code), coupleCode: code, uid: uid);
      },
    );
  }
}

class _CoupleChat extends ConsumerStatefulWidget {
  const _CoupleChat({super.key, required this.coupleCode, required this.uid});

  final String coupleCode;
  final String uid;

  @override
  ConsumerState<_CoupleChat> createState() => _CoupleChatState();
}

enum _PendingState { sending, failed }

class _PendingMessage {
  _PendingMessage({required this.id, required this.text, this.quickId})
    : state = _PendingState.sending;

  final String id;
  final String text;
  final String? quickId;
  _PendingState state;
  String? error;
}

class _CoupleChatState extends ConsumerState<_CoupleChat> {
  static const quickMessages = <String, String>{
    'miss_you': 'Te extraño',
    'need_you': 'Te necesito',
    'connect': 'Conéctate',
    'call_me': 'Llámame',
    'love_you': 'Te amo',
    'thinking_of_you': 'Pienso en ti',
  };

  final _message = TextEditingController();
  final _scroll = ScrollController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _older = [];
  final List<_PendingMessage> _pending = [];
  Timer? _typingDebounce;
  Timer? _typingStop;
  DateTime? _lastTypingPing;
  bool _typingActive = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _lastReadMessageId;

  ChatService get _chat => ref.read(chatServiceProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingStop?.cancel();
    if (_typingActive) {
      unawaited(_chat.setTyping(widget.coupleCode, false).catchError((_) {}));
    }
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 180) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore) return;
    final cursor = _older.isNotEmpty ? _older.last : _latestCursor;
    if (cursor == null) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _chat.loadOlder(widget.coupleCode, cursor);
      final known = _older.map((document) => document.id).toSet();
      _older.addAll(page.messages.where((document) => known.add(document.id)));
      _hasMore = page.hasMore;
    } on ChatException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _latestCursor;

  void _onChanged(String value) {
    _typingDebounce?.cancel();
    _typingStop?.cancel();
    if (value.trim().isEmpty) {
      _setTyping(false);
      return;
    }
    _typingDebounce = Timer(const Duration(milliseconds: 400), () {
      final stale =
          _lastTypingPing == null ||
          DateTime.now().difference(_lastTypingPing!) >
              const Duration(seconds: 2);
      if (!_typingActive || stale) _setTyping(true);
    });
    _typingStop = Timer(const Duration(seconds: 3), () => _setTyping(false));
    setState(() {});
  }

  void _setTyping(bool value) {
    if (_typingActive == value && !value) return;
    _typingActive = value;
    _lastTypingPing = value ? DateTime.now() : null;
    unawaited(_chat.setTyping(widget.coupleCode, value).catchError((_) {}));
  }

  Future<void> _sendText() async {
    final draft = _message.text.trim();
    if (draft.isEmpty) return;
    if (draft.length > 2000) {
      _show('El mensaje no puede superar 2000 caracteres.');
      return;
    }
    _message.clear();
    _setTyping(false);
    final pending = _PendingMessage(
      id: _chat.newMessageId(widget.coupleCode),
      text: draft,
    );
    setState(() => _pending.insert(0, pending));
    await _deliver(pending);
  }

  Future<void> _sendQuick(String id, String text) async {
    final pending = _PendingMessage(
      id: _chat.newMessageId(widget.coupleCode),
      text: text,
      quickId: id,
    );
    setState(() => _pending.insert(0, pending));
    await _deliver(pending);
  }

  Future<void> _deliver(_PendingMessage pending) async {
    setState(() {
      pending.state = _PendingState.sending;
      pending.error = null;
    });
    try {
      if (pending.quickId == null) {
        await _chat.sendMessage(
          widget.coupleCode,
          pending.text,
          messageId: pending.id,
        );
      } else {
        await _chat.sendQuickMessage(
          widget.coupleCode,
          pending.quickId!,
          messageId: pending.id,
        );
      }
      if (mounted) setState(() => _pending.remove(pending));
    } on ChatException catch (error) {
      if (!mounted) return;
      setState(() {
        pending.state = _PendingState.failed;
        pending.error = error.message;
      });
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar fotografía'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      await ref
          .read(sharedMediaServiceProvider)
          .pickAndShare(
            widget.coupleCode,
            source: source,
            onProgress: (progress) {
              if (mounted) setState(() => _uploadProgress = progress);
            },
          );
    } on SharedMediaException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text(
          'Puedes eliminar tus mensajes para ambos durante 10 minutos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar para ambos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _chat.deleteMessage(
        coupleCode: widget.coupleCode,
        messageId: messageId,
      );
    } on ChatException catch (error) {
      _show(error.message);
    }
  }

  void _markLatestRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final incoming = docs.where((document) {
      return document.data()['uploadedBy']?.toString() != widget.uid;
    }).firstOrNull;
    if (incoming == null || incoming.id == _lastReadMessageId) return;
    _lastReadMessageId = incoming.id;
    unawaited(
      _chat
          .markRead(coupleCode: widget.coupleCode, messageId: incoming.id)
          .catchError((_) {}),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chat.watchCouple(widget.coupleCode),
      builder: (context, coupleSnapshot) {
        final couple = coupleSnapshot.data?.data() ?? const <String, dynamic>{};
        final partnerUid = couple['user1'] == widget.uid
            ? couple['user2']?.toString() ?? ''
            : couple['user1']?.toString() ?? '';
        final profiles = _map(couple['memberProfiles']);
        final partner = _map(profiles[partnerUid]);
        final partnerName = partner['name']?.toString() ?? 'Tu pareja';
        final readState = _map(_map(couple['chatReadState'])[partnerUid]);
        final partnerReadAt = (readState['readAt'] as Timestamp?)?.toDate();
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: _ChatTitle(
              name: partnerName,
              coupleCode: widget.coupleCode,
              partnerUid: partnerUid,
            ),
            actions: [
              IconButton(
                tooltip: 'Notificaciones y privacidad',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              _QuickMessages(messages: quickMessages, onTap: _sendQuick),
              if (_uploading)
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chat.watchLatest(widget.coupleCode),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('No se pudo cargar el chat.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final latest = snapshot.data!.docs;
                    if (latest.isNotEmpty) _latestCursor = latest.last;
                    final known = latest.map((document) => document.id).toSet();
                    final messages =
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[
                          ...latest,
                          ..._older.where((document) => known.add(document.id)),
                        ];
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _markLatestRead(latest),
                    );
                    if (messages.isEmpty && _pending.isEmpty) {
                      return const _EmptyChat();
                    }
                    final firstOwn = messages.indexWhere(
                      (document) => document.data()['uploadedBy'] == widget.uid,
                    );
                    return Column(
                      children: [
                        if (snapshot.data!.metadata.isFromCache)
                          const _OfflineBanner(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: _pending.length + messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index < _pending.length) {
                                return _PendingBubble(
                                  pending: _pending[index],
                                  onRetry: () => _deliver(_pending[index]),
                                );
                              }
                              final messageIndex = index - _pending.length;
                              if (messageIndex == messages.length) {
                                return _HistoryLoader(
                                  loading: _loadingOlder,
                                  hasMore: _hasMore,
                                  onTap: _loadOlder,
                                );
                              }
                              final document = messages[messageIndex];
                              final data = document.data();
                              final mine = data['uploadedBy'] == widget.uid;
                              final createdAt =
                                  (data['timestamp'] as Timestamp?)?.toDate();
                              final read =
                                  mine &&
                                  messageIndex == firstOwn &&
                                  partnerReadAt != null &&
                                  createdAt != null &&
                                  !partnerReadAt.isBefore(createdAt);
                              return _MessageBubble(
                                document: document,
                                mine: mine,
                                read: read,
                                coupleCode: widget.coupleCode,
                                onDelete: mine
                                    ? () => _deleteMessage(document.id)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (partnerUid.isNotEmpty)
                _TypingIndicator(
                  coupleCode: widget.coupleCode,
                  partnerUid: partnerUid,
                ),
              _Composer(
                controller: _message,
                uploading: _uploading,
                onChanged: _onChanged,
                onPhoto: _choosePhoto,
                onSend: _sendText,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({
    required this.name,
    required this.coupleCode,
    required this.partnerUid,
  });
  final String name;
  final String coupleCode;
  final String partnerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.read(chatServiceProvider).watchCouple(coupleCode),
      builder: (context, snapshot) {
        final presence = _map(
          _map(snapshot.data?.data()?['memberPresence'])[partnerUid],
        );
        final lastSeen = presence['lastSeenAt'] as Timestamp?;
        final fresh =
            presence['online'] == true &&
            lastSeen != null &&
            DateTime.now().difference(lastSeen.toDate()) <=
                const Duration(minutes: 3);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              fresh ? 'En línea' : _lastSeenText(lastSeen?.toDate()),
              style: TextStyle(
                fontSize: 11,
                color: fresh ? Colors.green.shade700 : Colors.black54,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickMessages extends StatelessWidget {
  const _QuickMessages({required this.messages, required this.onTap});
  final Map<String, String> messages;
  final void Function(String id, String text) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: messages.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            avatar: const Icon(Icons.favorite_rounded, size: 16),
            label: Text(entry.value),
            onPressed: () => onTap(entry.key, entry.value),
          ),
        );
      }).toList(),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.uploading,
    required this.onChanged,
    required this.onPhoto,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool uploading;
  final ValueChanged<String> onChanged;
  final VoidCallback onPhoto;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            tooltip: 'Enviar fotografía',
            onPressed: uploading ? null : onPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje…',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => IconButton.filled(
              tooltip: 'Enviar',
              onPressed: value.text.trim().isEmpty ? null : onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.document,
    required this.mine,
    required this.read,
    required this.coupleCode,
    required this.onDelete,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool mine;
  final bool read;
  final String coupleCode;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = document.data();
    final isImage = data['type'] == 'image';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: isImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.fromLTRB(13, 9, 11, 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .76,
          ),
          decoration: BoxDecoration(
            color: mine
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isImage)
                _AuthenticatedPhoto(
                  coupleCode: coupleCode,
                  messageId: document.id,
                  storagePath: data['storagePath']?.toString() ?? '',
                )
              else
                Text(
                  data['text']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: data['type'] == 'quick'
                        ? FontWeight.w700
                        : null,
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeText(timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      read ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: read ? Colors.blue : Colors.black45,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.pending, required this.onRetry});
  final _PendingMessage pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: InkWell(
      onTap: pending.state == _PendingState.failed ? onRetry : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .76,
        ),
        decoration: BoxDecoration(
          color: pending.state == _PendingState.failed
              ? Colors.red.shade50
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pending.text),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pending.state == _PendingState.failed
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
                  size: 14,
                  color: pending.state == _PendingState.failed
                      ? Colors.red
                      : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  pending.state == _PendingState.failed
                      ? 'Error · Toca para reintentar'
                      : 'Enviando',
                  style: TextStyle(
                    fontSize: 10,
                    color: pending.state == _PendingState.failed
                        ? Colors.red
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthenticatedPhoto extends ConsumerStatefulWidget {
  const _AuthenticatedPhoto({
    required this.coupleCode,
    required this.messageId,
    required this.storagePath,
  });
  final String coupleCode;
  final String messageId;
  final String storagePath;

  @override
  ConsumerState<_AuthenticatedPhoto> createState() =>
      _AuthenticatedPhotoState();
}

class _AuthenticatedPhotoState extends ConsumerState<_AuthenticatedPhoto> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = _load();
  }

  Future<Uint8List> _load() => ref
      .read(sharedMediaServiceProvider)
      .loadPhoto(
        coupleCode: widget.coupleCode,
        storagePath: widget.storagePath,
        cacheKey: widget.messageId,
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            width: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return InkWell(
            onTap: () => setState(() => _photo = _load()),
            child: const SizedBox(
              height: 130,
              width: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined),
                  SizedBox(height: 6),
                  Text('No se pudo cargar · Reintentar'),
                ],
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _PhotoViewer(bytes: snapshot.data!),
            ),
          ),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            cacheWidth: 720,
            gaplessPlayback: true,
          ),
        );
      },
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
  );
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator({required this.coupleCode, required this.partnerUid});
  final String coupleCode;
  final String partnerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.read(chatServiceProvider).watchTyping(coupleCode, partnerUid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final updatedAt = data?['updatedAt'] as Timestamp?;
        final active =
            data?['isTyping'] == true &&
            updatedAt != null &&
            DateTime.now().difference(updatedAt.toDate()) <
                const Duration(seconds: 8);
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: active
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 3, 16, 3),
                    child: Text(
                      'Tu pareja está escribiendo…',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _HistoryLoader extends StatelessWidget {
  const _HistoryLoader({
    required this.loading,
    required this.hasMore,
    required this.onTap,
  });
  final bool loading;
  final bool hasMore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox(height: 18);
    return Center(
      child: TextButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.history_rounded),
        label: Text(loading ? 'Cargando…' : 'Cargar mensajes anteriores'),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Colors.amber.shade100,
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
    child: const Text(
      'Mostrando la copia guardada · La sincronización se reintentará al conectar',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_outline_rounded, size: 54),
          SizedBox(height: 12),
          Text(
            'Este es su espacio privado',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Escribe un mensaje o usa un acceso rápido.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _timeText(DateTime? date) {
  if (date == null) return 'Enviando';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _lastSeenText(DateTime? date) {
  if (date == null) return 'Desconectado';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Visto hace un momento';
  if (difference.inMinutes < 60) {
    return 'Visto hace ${difference.inMinutes} min';
  }
  if (difference.inHours < 24) return 'Visto hace ${difference.inHours} h';
  return 'Desconectado';
}
