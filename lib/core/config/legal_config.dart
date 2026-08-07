class PawdoLegalConfig {
  const PawdoLegalConfig._();

  static const privacyUrl = String.fromEnvironment('PAWDO_PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('PAWDO_TERMS_URL');
  static const deletionUrl = String.fromEnvironment('PAWDO_DELETION_URL');
  static const supportEmail = String.fromEnvironment('PAWDO_SUPPORT_EMAIL');

  static bool _isHttps(String value) =>
      Uri.tryParse(value)?.scheme.toLowerCase() == 'https';

  static bool get publicationLinksReady =>
      _isHttps(privacyUrl) &&
      _isHttps(termsUrl) &&
      _isHttps(deletionUrl) &&
      supportEmail.contains('@');
}
