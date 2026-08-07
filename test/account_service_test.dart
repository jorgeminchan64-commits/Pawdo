import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/config/legal_config.dart';
import 'package:pawdo/features/account/services/account_service.dart';

void main() {
  test('account export filename is UTC-safe and portable', () {
    final name = accountExportFileName(DateTime.parse('2026-08-07T10:20:30Z'));
    expect(name, 'pawdo-datos-2026-08-07T10-20-30.000Z.json');
    expect(name, isNot(contains(':')));
  });

  test('account export JSON is readable and preserves nested data', () {
    final encoded = encodeAccountExport({
      'schemaVersion': 1,
      'account': {'email': 'persona@example.com'},
      'firestoreDocuments': [
        {'path': 'users/one'},
      ],
    });
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 1);
    expect(
      (decoded['account'] as Map<String, dynamic>)['email'],
      'persona@example.com',
    );
    expect(encoded, contains('\n  "schemaVersion"'));
  });

  test('published legal and support resources are configured by default', () {
    expect(PawdoLegalConfig.publicationLinksReady, isTrue);
    expect(PawdoLegalConfig.privacyUrl, startsWith('https://'));
    expect(PawdoLegalConfig.termsUrl, startsWith('https://'));
    expect(PawdoLegalConfig.deletionUrl, startsWith('https://'));
    expect(PawdoLegalConfig.supportEmail, 'soporte.pawdo@gmail.com');
    expect(PawdoLegalConfig.deletionEmail, 'borrado.pawdo@gmail.com');
  });
}
