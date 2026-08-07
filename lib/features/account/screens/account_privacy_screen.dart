import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_config.dart';
import '../../../core/services/android_widget_service.dart';
import '../../location/services/location_sharing_service.dart';
import '../services/account_service.dart';
import 'legal_document_screen.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  final _service = AccountService();
  bool _busy = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final file = await _service.exportData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exportaci\u00f3n lista'),
          content: SelectableText(
            'Guardamos un archivo JSON en:\n\n${file.path}\n\n'
            'Incluye datos estructurados y rutas de archivos, no las im\u00e1genes binarias.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } on AccountException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    final values = await showDialog<({String email, String password})>(
      context: context,
      builder: (_) => const _EmailDialog(),
    );
    if (values == null) return;
    setState(() => _busy = true);
    try {
      await _service.requestEmailChange(
        newEmail: values.email,
        password: values.password,
      );
      _message(
        'Revisa ${values.email}. El correo cambiar\u00e1 cuando abras el enlace de verificaci\u00f3n.',
      );
    } on AccountException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final values = await showDialog<({String confirmation, String password})>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (values == null) return;
    setState(() => _busy = true);
    try {
      await _service.deleteAccount(
        password: values.password,
        confirmation: values.confirmation,
      );
      await AndroidWidgetService.instance.clear();
      try {
        await LocationSharingService().stop();
      } catch (_) {
        // El servidor ya elimin\u00f3 la sesi\u00f3n y todos sus datos.
      }
      await FirebaseAuth.instance.signOut();
    } on AccountException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? 'Correo no disponible';
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(title: const Text('Cuenta y privacidad')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Section(
                title: 'Cuenta',
                children: [
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: const Text('Correo'),
                    subtitle: Text(email),
                    trailing: const Text('Cambiar'),
                    onTap: _busy ? null : _changeEmail,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Descargar mis datos'),
                    subtitle: const Text(
                      'Guardar una copia JSON en el dispositivo',
                    ),
                    onTap: _busy ? null : _export,
                  ),
                ],
              ),
              _Section(
                title: 'Privacidad y ayuda',
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Pol\u00edtica de privacidad'),
                    onTap: () => _openLegal(LegalDocument.privacy),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('T\u00e9rminos de uso'),
                    onTap: () => _openLegal(LegalDocument.terms),
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Reportar un problema'),
                    subtitle: Text(
                      PawdoLegalConfig.supportEmail.isEmpty
                          ? 'Canal de soporte pendiente de configurar'
                          : PawdoLegalConfig.supportEmail,
                    ),
                    onTap: _contactSupport,
                  ),
                  if (PawdoLegalConfig.deletionUrl.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: const Text('Solicitud de borrado en la web'),
                      subtitle: Text(PawdoLegalConfig.deletionEmail),
                      onTap: () => launchUrl(
                        Uri.parse(PawdoLegalConfig.deletionUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                ],
              ),
              if (!PawdoLegalConfig.publicationLinksReady)
                const Card(
                  color: Color(0xFFFFF0CE),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Preparaci\u00f3n para Play Store: faltan URLs p\u00fablicas reales '
                      'de privacidad, t\u00e9rminos y borrado, adem\u00e1s del correo de soporte.',
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFFFFE8E8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zona de peligro',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF9C1F33),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'La eliminaci\u00f3n es permanente y borra tambi\u00e9n el '
                        'historial, juegos y fotos del espacio compartido para tu pareja.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9C1F33),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Eliminar mi cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  Future<void> _contactSupport() async {
    final email = PawdoLegalConfig.supportEmail;
    if (email.isEmpty) {
      _message(
        'El responsable debe configurar un correo de soporte antes de publicar.',
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Reporte desde Pawdo'},
    );
    if (!await launchUrl(uri)) _message('No se pudo abrir una app de correo.');
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    ),
  );
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog();

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar correo'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enviaremos un enlace de verificaci\u00f3n al nuevo correo.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Nuevo correo'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contrase\u00f1a actual',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          email: email.text,
          password: password.text,
        )),
        child: const Text('Verificar'),
      ),
    ],
  );
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final confirmation = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    confirmation.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Eliminar cuenta definitivamente'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrar\u00e1n tu cuenta, perfil, datos privados, foto y todo el '
            'espacio compartido. Tu pareja tambi\u00e9n perder\u00e1 ese historial. '
            'Descarga antes una copia si deseas conservarlo.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirmation,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Escribe ELIMINAR'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contrase\u00f1a actual',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: confirmation.text == 'ELIMINAR' && password.text.isNotEmpty
            ? () => Navigator.pop(context, (
                confirmation: confirmation.text,
                password: password.text,
              ))
            : null,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9C1F33)),
        child: const Text('Borrar para siempre'),
      ),
    ],
  );
}
