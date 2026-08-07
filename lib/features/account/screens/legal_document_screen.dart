import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_config.dart';

enum LegalDocument { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final privacy = document == LegalDocument.privacy;
    final url = privacy
        ? PawdoLegalConfig.privacyUrl
        : PawdoLegalConfig.termsUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          privacy ? 'Pol\u00edtica de privacidad' : 'T\u00e9rminos de uso',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Pawdo \u00b7 versi\u00f3n informativa del 7 de agosto de 2026',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          ...(privacy ? _privacySections : _termsSections).map(
            (section) => _LegalSection(section: section),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir versi\u00f3n publicada'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Card(
              color: Color(0xFFFFF0CE),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Pendiente de publicaci\u00f3n: antes de distribuir Pawdo se debe '
                  'configurar la URL p\u00fablica y la identidad legal del responsable.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.section});

  final ({String title, String body}) section;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(section.body, style: const TextStyle(height: 1.45)),
      ],
    ),
  );
}

const _privacySections = <({String title, String body})>[
  (
    title: 'Responsable',
    body:
        'Pawdo es desarrollada de forma independiente en Perú por Jorge Luis '
        'Minchan Huaman. Para privacidad o soporte puedes escribir a '
        'soporte.pawdo@gmail.com.',
  ),
  (
    title: 'Qu\u00e9 datos utiliza Pawdo',
    body:
        'La cuenta usa correo e identificador de Firebase. El perfil puede incluir '
        'nombre, foto, cumplea\u00f1os y fecha de relaci\u00f3n. Las funciones elegidas '
        'por la persona pueden guardar mensajes, fotos, actividad de pareja, '
        'preferencias de notificaci\u00f3n, token del dispositivo, datos de bienestar '
        'y ubicaci\u00f3n temporal.',
  ),
  (
    title: 'Finalidad y acceso',
    body:
        'Los datos se usan para autenticar, sincronizar la experiencia y mostrar '
        'contenido a la pareja vinculada. Bienestar es privado por defecto y solo '
        'comparte los campos consentidos. La ubicaci\u00f3n requiere una sesi\u00f3n '
        'iniciada por la persona y tiene vencimiento de seguridad.',
  ),
  (
    title: 'Proveedores y seguridad',
    body:
        'Pawdo utiliza servicios Firebase de Google para autenticaci\u00f3n, base de '
        'datos, archivos, funciones y notificaciones. El acceso se limita con reglas '
        'de seguridad, operaciones validadas en servidor y conexiones cifradas en '
        'tr\u00e1nsito. Pawdo no declara vender datos personales.',
  ),
  (
    title: 'C\u00e1mara, micr\u00f3fono y ubicaci\u00f3n',
    body:
        'La c\u00e1mara se usa cuando eliges una foto. La ubicaci\u00f3n se solicita '
        'solo al iniciar el uso compartido temporal. Las llamadas siguen en '
        'desarrollo; abrir su diagn\u00f3stico no inicia una llamada ni transmite audio.',
  ),
  (
    title: 'Conservaci\u00f3n, exportaci\u00f3n y borrado',
    body:
        'Puedes descargar un JSON con los datos estructurados de tu cuenta. Al '
        'eliminarla se borran el usuario de autenticaci\u00f3n, el perfil y sus datos '
        'privados, la foto de perfil y todo el espacio compartido de la pareja, '
        'incluido su historial y fotos. Esa eliminaci\u00f3n afecta a ambos miembros '
        'y no se puede deshacer.',
  ),
  (
    title: 'Tus controles',
    body:
        'Puedes editar el perfil, detener la ubicaci\u00f3n, retirar el '
        'consentimiento de bienestar, borrar ese historial, exportar datos, '
        'desvincular la pareja o eliminar definitivamente la cuenta.',
  ),
];

const _termsSections = <({String title, String body})>[
  (
    title: 'Responsable y aceptación',
    body:
        'Pawdo es desarrollada de forma independiente por Jorge Luis Minchan '
        'Huaman. Al crear una cuenta o usarla, aceptas estas condiciones y la '
        'política de privacidad.',
  ),
  (
    title: 'Uso de Pawdo',
    body:
        'Pawdo ofrece una experiencia privada para dos personas. Debes usar una '
        'cuenta propia, proteger tus credenciales y contar con permiso para subir '
        'fotos o contenido de terceros.',
  ),
  (
    title: 'Respeto y contenido',
    body:
        'No uses Pawdo para acosar, amenazar, infringir derechos, distribuir '
        'contenido ilegal ni intentar acceder a datos de otras personas. Puedes '
        'reportar problemas mediante el canal de soporte configurado.',
  ),
  (
    title: 'Funciones compartidas',
    body:
        'Vincular una pareja concede acceso mutuo al espacio compartido. '
        'Desvincular revoca el acceso y archiva los datos. Eliminar una cuenta '
        'borra permanentemente el espacio compartido para ambas personas.',
  ),
  (
    title: 'Disponibilidad',
    body:
        'Las funciones pueden cambiar o interrumpirse por mantenimiento. Las '
        'llamadas est\u00e1n marcadas como en desarrollo y no deben interpretarse '
        'como una funci\u00f3n disponible.',
  ),
  (
    title: 'Cambios y contacto',
    body:
        'Las condiciones y pr\u00e1cticas de datos deben publicarse con fecha de '
        'vigencia. La versi\u00f3n final debe identificar al responsable legal y un '
        'canal de contacto antes de publicar la aplicaci\u00f3n.',
  ),
];
