import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/services/crash_reporting_service.dart';

void main() {
  test('reported errors retain only their runtime type', () {
    const privateMessage = 'correo@ejemplo.com: mensaje privado';
    final source = Exception(privateMessage);
    final safe = PawdoReportedError(source.runtimeType.toString());

    expect(safe.toString(), contains('Exception'));
    expect(safe.toString(), isNot(contains(privateMessage)));
    expect(safe.toString(), isNot(contains('correo@ejemplo.com')));
  });
}
