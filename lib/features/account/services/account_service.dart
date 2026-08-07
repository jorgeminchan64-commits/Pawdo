import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

String accountExportFileName(DateTime now) {
  final stamp = now.toUtc().toIso8601String().replaceAll(':', '-');
  return 'pawdo-datos-$stamp.json';
}

String encodeAccountExport(Map<String, dynamic> data) =>
    const JsonEncoder.withIndent('  ').convert(data);

class AccountService {
  AccountService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountException('Inicia sesi\u00f3n para continuar.');
    }
    return user;
  }

  Future<void> reauthenticate(String password) async {
    final user = _user;
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AccountException(
        'Esta cuenta no tiene un correo disponible para confirmar su identidad.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AccountException(switch (error.code) {
        'wrong-password' ||
        'invalid-credential' => 'La contrase\u00f1a no es correcta.',
        'too-many-requests' =>
          'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.',
        _ => 'No se pudo confirmar tu identidad.',
      });
    }
  }

  Future<void> requestEmailChange({
    required String newEmail,
    required String password,
  }) async {
    final email = newEmail.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const AccountException('Escribe un correo v\u00e1lido.');
    }
    await reauthenticate(password);
    try {
      await _user.verifyBeforeUpdateEmail(email);
    } on FirebaseAuthException catch (error) {
      throw AccountException(switch (error.code) {
        'email-already-in-use' => 'Ese correo ya est\u00e1 registrado.',
        'invalid-email' => 'Escribe un correo v\u00e1lido.',
        _ => 'No se pudo enviar la verificaci\u00f3n al nuevo correo.',
      });
    }
  }

  Future<File> exportData() async {
    try {
      final callable = _functions.httpsCallable('exportAccountData');
      final result = await callable.call<Map<String, dynamic>>();
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}${accountExportFileName(DateTime.now())}',
      );
      await file.writeAsString(encodeAccountExport(result.data), flush: true);
      return file;
    } on FirebaseFunctionsException catch (error) {
      throw AccountException(
        error.message ?? 'No se pudo preparar la exportaci\u00f3n.',
      );
    } on FileSystemException {
      throw const AccountException(
        'No se pudo guardar el archivo en este dispositivo.',
      );
    }
  }

  Future<void> deleteAccount({
    required String password,
    required String confirmation,
  }) async {
    await reauthenticate(password);
    try {
      await _functions.httpsCallable('deleteAccount').call<void>({
        'confirm': true,
        'confirmation': confirmation,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AccountException(error.message ?? 'No se pudo eliminar la cuenta.');
    }
  }
}
