import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/services/chat_service.dart';
import '../../features/couple/services/couple_service.dart';
import '../../features/media/services/shared_media_service.dart';
import '../../features/pet/services/pet_service.dart';

final coupleServiceProvider = Provider<CoupleService>((ref) => CoupleService());
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
final sharedMediaServiceProvider = Provider<SharedMediaService>(
  (ref) => SharedMediaService(chatService: ref.read(chatServiceProvider)),
);
final petServiceProvider = Provider<PetService>((ref) => PetService());
