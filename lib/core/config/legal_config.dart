class PawdoLegalConfig {
  const PawdoLegalConfig._();

  static const privacyUrl = String.fromEnvironment(
    'PAWDO_PRIVACY_URL',
    defaultValue:
        'https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/privacidad',
  );
  static const termsUrl = String.fromEnvironment(
    'PAWDO_TERMS_URL',
    defaultValue:
        'https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/terminos',
  );
  static const deletionUrl = String.fromEnvironment(
    'PAWDO_DELETION_URL',
    defaultValue:
        'https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/eliminar-cuenta',
  );
  static const supportEmail = String.fromEnvironment(
    'PAWDO_SUPPORT_EMAIL',
    defaultValue: 'soporte.pawdo@gmail.com',
  );
  static const deletionEmail = String.fromEnvironment(
    'PAWDO_DELETION_EMAIL',
    defaultValue: 'borrado.pawdo@gmail.com',
  );

  static bool _isHttps(String value) =>
      Uri.tryParse(value)?.scheme.toLowerCase() == 'https';

  static bool get publicationLinksReady =>
      _isHttps(privacyUrl) &&
      _isHttps(termsUrl) &&
      _isHttps(deletionUrl) &&
      supportEmail.contains('@');
}
