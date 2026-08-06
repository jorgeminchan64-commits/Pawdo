import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatException implements Exception {
  const ChatException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class ChatPage {
  const ChatPage(this.messages, this.lastDocument, this.hasMore);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  static const int pageSize = 30;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _messages(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('chat');

  String newMessageId(String coupleCode) => _messages(coupleCode).doc().id;

  Future<String> sendMessage(
    String coupleCode,
    String message, {
    String? messageId,
  }) async {
    _requireUser();
    final text = message.trim();
    if (text.isEmpty || text.length > 2000) {
      throw const ChatException(
        'El mensaje debe tener entre 1 y 2000 caracteres.',
      );
    }
    final id = messageId ?? newMessageId(coupleCode);
    await _call('sendChatMessage', {
      'coupleCode': coupleCode,
      'messageId': id,
      'text': text,
    });
    return id;
  }

  Future<String> sendQuickMessage(
    String coupleCode,
    String quickId, {
    String? messageId,
  }) async {
    _requireUser();
    final id = messageId ?? newMessageId(coupleCode);
    await _call('sendChatMessage', {
      'coupleCode': coupleCode,
      'messageId': id,
      'quickId': quickId,
    });
    return id;
  }

  Future<void> finalizePhotoMetadata({
    required String messageId,
    required String coupleCode,
    required String storagePath,
    required String fileName,
  }) => _call('finalizePhotoMessage', {
    'messageId': messageId,
    'coupleCode': coupleCode,
    'storagePath': storagePath,
    'fileName': fileName,
  });

  Future<void> discardPhotoUpload({
    required String coupleCode,
    required String storagePath,
    required String fileName,
  }) => _call('discardPhotoUpload', {
    'coupleCode': coupleCode,
    'storagePath': storagePath,
    'fileName': fileName,
  });

  Future<void> deleteMessage({
    required String coupleCode,
    required String messageId,
  }) => _call('deleteChatMessage', {
    'coupleCode': coupleCode,
    'messageId': messageId,
  });

  Future<void> markRead({
    required String coupleCode,
    required String messageId,
  }) =>
      _call('markChatRead', {'coupleCode': coupleCode, 'messageId': messageId});

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLatest(
    String coupleCode, {
    int limit = pageSize,
  }) => _messages(coupleCode)
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true);

  Future<ChatPage> loadOlder(
    String coupleCode,
    QueryDocumentSnapshot<Map<String, dynamic>> after, {
    int limit = pageSize,
  }) async {
    final snapshot = await _messages(coupleCode)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(after)
        .limit(limit)
        .get(const GetOptions(source: Source.serverAndCache));
    return ChatPage(
      snapshot.docs,
      snapshot.docs.isEmpty ? after : snapshot.docs.last,
      snapshot.docs.length == limit,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCouple(
    String coupleCode,
  ) => _db.collection('couples').doc(coupleCode).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTyping(
    String coupleCode,
    String partnerUid,
  ) => _db
      .collection('couples')
      .doc(coupleCode)
      .collection('typing')
      .doc(partnerUid)
      .snapshots();

  Future<void> setTyping(String coupleCode, bool isTyping) async {
    final uid = _requireUser().uid;
    await _db
        .collection('couples')
        .doc(coupleCode)
        .collection('typing')
        .doc(uid)
        .set({
          'uid': uid,
          'isTyping': isTyping,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ChatException('Inicia sesión para chatear.');
    }
    return user;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      throw ChatException(
        message?.isNotEmpty == true
            ? message!
            : 'No se pudo completar la operación del chat.',
        retryable:
            error.code == 'unavailable' ||
            error.code == 'aborted' ||
            error.code == 'deadline-exceeded',
      );
    } on FirebaseException catch (_) {
      throw const ChatException(
        'No se pudo conectar con Firebase.',
        retryable: true,
      );
    }
  }
}
