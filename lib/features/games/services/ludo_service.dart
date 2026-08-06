import 'package:cloud_functions/cloud_functions.dart';

class LudoMoveResult {
  const LudoMoveResult({
    required this.moved,
    required this.won,
    required this.winnerSide,
    required this.winnerName,
    required this.rewardAwarded,
  });

  final bool moved;
  final bool won;
  final String winnerSide;
  final String winnerName;
  final bool rewardAwarded;
}

class LudoRestartResult {
  const LudoRestartResult({required this.restarted, required this.approved});

  final bool restarted;
  final bool approved;
}

class LudoService {
  LudoService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> join(String coupleCode) =>
      _call('joinLudo', coupleCode: coupleCode);

  Future<void> rollDice(String coupleCode) =>
      _call('rollLudoDice', coupleCode: coupleCode);

  Future<LudoMoveResult> moveToken({
    required String coupleCode,
    required int tokenIndex,
  }) async {
    final result = await _functions.httpsCallable('moveLudoToken').call(
      <String, dynamic>{'coupleCode': coupleCode, 'tokenIndex': tokenIndex},
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return LudoMoveResult(
      moved: data['moved'] == true,
      won: data['won'] == true,
      winnerSide: data['winnerSide']?.toString() ?? '',
      winnerName: data['winnerName']?.toString() ?? '',
      rewardAwarded: data['rewardAwarded'] == true,
    );
  }

  Future<LudoRestartResult> reset(String coupleCode) async {
    final data = await _call('resetLudo', coupleCode: coupleCode);
    return LudoRestartResult(
      restarted: data['reset'] == true,
      approved: data['approved'] == true,
    );
  }

  Future<void> abandon(String coupleCode) =>
      _call('abandonLudo', coupleCode: coupleCode);

  Future<Map<String, dynamic>> _call(
    String name, {
    required String coupleCode,
  }) async {
    final result = await _functions.httpsCallable(name).call(<String, dynamic>{
      'coupleCode': coupleCode,
    });
    return Map<String, dynamic>.from(result.data as Map? ?? const {});
  }
}
