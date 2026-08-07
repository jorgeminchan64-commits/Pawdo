import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../media/services/shared_media_service.dart';
import '../models/profile_data.dart';
import '../services/profile_service.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile, this.repository});

  final ProfileData profile;
  final ProfileRepository? repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileRepository _service = widget.repository ?? ProfileService();
  late final TextEditingController _nameController;
  late final TextEditingController _displayNameController;
  late DateTime? _birthday;
  late DateTime? _relationshipStartDate;
  late ProfileTheme _theme;
  File? _newPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _birthday = widget.profile.birthday;
    _relationshipStartDate = widget.profile.relationshipStartDate;
    _theme = widget.profile.theme;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
      );
      if (selected != null && mounted) {
        setState(() => _newPhoto = File(selected.path));
      }
    } catch (_) {
      _showMessage('No se pudo abrir la galería. Revisa los permisos.');
    }
  }

  Future<void> _pickDate({required bool birthday}) async {
    final now = DateTime.now();
    final current = birthday ? _birthday : _relationshipStartDate;
    final selected = await showDatePicker(
      context: context,
      initialDate:
          current ?? (birthday ? DateTime(now.year - 18) : DateTime.now()),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: birthday ? 'Selecciona tu cumpleaños' : 'Inicio de la relación',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (birthday) {
        _birthday = selected;
      } else {
        _relationshipStartDate = selected;
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null || _relationshipStartDate == null) {
      _showMessage('Completa ambas fechas para guardar.');
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoPath;
      if (_newPhoto != null) {
        photoPath = await _service.uploadProfilePhoto(_newPhoto!);
      }
      await _service.updateProfile(
        name: _nameController.text,
        displayName: _displayNameController.text,
        birthday: _birthday!,
        relationshipStartDate: _relationshipStartDate!,
        theme: _theme,
        photoStoragePath: photoPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SharedMediaException catch (error) {
      _showMessage(error.message);
    } on ProfileException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo actualizar el perfil. Inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateName(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return 'Este campo es obligatorio';
    if (clean.length > 80) return 'Usa como máximo 80 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const ValueKey('edit_profile_form'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Cambiar foto de perfil',
                  child: InkWell(
                    onTap: _saving ? null : _pickPhoto,
                    customBorder: const CircleBorder(),
                    child: ProfileAvatar(
                      radius: 58,
                      storagePath: widget.profile.photoStoragePath,
                      localFile: _newPhoto,
                      showEditBadge: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
                decoration: const InputDecoration(
                  labelText: 'Nombre visible',
                  helperText: 'Este es el nombre que verá tu pareja.',
                  prefixIcon: Icon(Icons.favorite_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _DateTile(
                icon: Icons.cake_outlined,
                label: 'Cumpleaños',
                value: formatProfileDate(_birthday),
                onTap: _saving ? null : () => _pickDate(birthday: true),
              ),
              const SizedBox(height: 12),
              _DateTile(
                icon: Icons.favorite_rounded,
                label: 'Inicio de la relación',
                value: formatProfileDate(_relationshipStartDate),
                onTap: _saving ? null : () => _pickDate(birthday: false),
              ),
              const SizedBox(height: 24),
              const Text(
                'Estilo del perfil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProfileTheme.values.map((theme) {
                  return ChoiceChip(
                    label: Text(_themeLabel(theme)),
                    selected: _theme == theme,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _theme = theme),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(ProfileTheme theme) => switch (theme) {
    ProfileTheme.rose => 'Rosa',
    ProfileTheme.lavender => 'Lavanda',
    ProfileTheme.sunset => 'Atardecer',
  };
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      leading: Icon(icon, color: const Color(0xFF7B3FA3)),
      title: Text(label),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.calendar_month_outlined),
    );
  }
}
