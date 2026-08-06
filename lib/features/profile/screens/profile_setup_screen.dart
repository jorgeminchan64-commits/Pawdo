import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../../media/services/shared_media_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nameController = TextEditingController();

  File? _profileImage;
  DateTime? _birthday;
  DateTime? _relationshipStartDate;
  bool isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
    );

    if (picked == null) return;

    setState(() {
      _profileImage = File(picked.path);
    });
  }

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  Future<void> pickRelationshipStartDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (selected != null) {
      setState(() => _relationshipStartDate = selected);
    }
  }

  Future<void> saveProfile() async {
    FocusScope.of(context).unfocus();

    if (_nameController.text.trim().isEmpty) {
      showMessage('Escribe tu nombre');
      return;
    }

    if (_birthday == null) {
      showMessage('Selecciona tu cumpleaños');
      return;
    }

    if (_relationshipStartDate == null) {
      showMessage('Selecciona el inicio de la relación');
      return;
    }

    setState(() => isLoading = true);

    try {
      String? photoStoragePath;

      if (_profileImage != null) {
        photoStoragePath = await _profileService.uploadProfilePhoto(
          _profileImage!,
        );
      }

      await _profileService.saveProfile(
        name: _nameController.text.trim(),
        birthday: _birthday!,
        relationshipStartDate: _relationshipStartDate!,
        photoStoragePath: photoStoragePath,
      );

      if (!mounted) return;

      showMessage('Perfil creado correctamente 🐶');
      // No usamos Navigator aquí. AuthGate detecta profileCompleted=true
      // y te manda automáticamente a Conectar pareja.
    } on SharedMediaException catch (e) {
      if (!mounted) return;
      showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Seleccionar fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF8E7BFF), Color(0xFFFF6584)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Crea tu perfil 🐶',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Primero personalizamos tu experiencia en Pawdo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),

                GestureDetector(
                  onTap: isLoading ? null : pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 62,
                        backgroundColor: Colors.white,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Color(0xFF6C63FF),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Toca para agregar foto de perfil',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 25),

                _input(
                  controller: _nameController,
                  hint: 'Tu nombre',
                  icon: Icons.badge,
                ),
                const SizedBox(height: 16),

                _dateButton(
                  title: 'Fecha de cumpleaños',
                  value: formatDate(_birthday),
                  icon: Icons.cake,
                  onTap: isLoading ? null : pickBirthday,
                ),
                const SizedBox(height: 16),

                _dateButton(
                  title: 'Inicio de la relación',
                  value: formatDate(_relationshipStartDate),
                  icon: Icons.favorite,
                  onTap: isLoading ? null : pickRelationshipStartDate,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: isLoading ? null : saveProfile,
                    child: Text(
                      isLoading ? 'Guardando...' : 'Continuar',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _dateButton({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_month),
          ],
        ),
      ),
    );
  }
}
