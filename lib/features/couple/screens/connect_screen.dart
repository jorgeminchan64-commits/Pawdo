import 'package:flutter/material.dart';
import '../services/couple_service.dart';

class ConnectScreen extends StatefulWidget {
  final String? existingCode;

  const ConnectScreen({super.key, this.existingCode});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController codeController = TextEditingController();
  final CoupleService _coupleService = CoupleService();

  String generatedCode = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    generatedCode = widget.existingCode ?? '';
  }

  @override
  void didUpdateWidget(covariant ConnectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCode = widget.existingCode ?? '';
    if (nextCode != (oldWidget.existingCode ?? '')) {
      generatedCode = nextCode;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> createCode() async {
    setState(() => isLoading = true);

    try {
      final code = await _coupleService.createCoupleCode();

      if (!mounted) return;

      setState(() {
        generatedCode = code;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código creado correctamente ❤️')),
      );
    } on CoupleException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear el código. Inténtalo nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> joinCode() async {
    if (codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un código')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await _coupleService.joinCouple(codeController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Pareja conectada! ❤️')));
      // No usamos Navigator. AuthGate detecta la pareja completa
      // y manda automáticamente al MainScreen.
    } on CoupleException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo unir la pareja. Inténtalo nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> cancelCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este código?'),
        content: const Text(
          'La invitación dejará de funcionar y podrás generar una nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar código'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => isLoading = true);
    try {
      await _coupleService.cancelCoupleInvitation();
      if (!mounted) return;
      setState(() => generatedCode = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código eliminado. Ya puedes generar otro.'),
        ),
      );
    } on CoupleException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar el código. Inténtalo nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> repairConnection() async {
    setState(() => isLoading = true);
    try {
      final result = await _coupleService.repairCoupleMembership();
      if (!mounted) return;
      final state = result['state']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state == 'paired'
                ? 'Conexión recuperada correctamente.'
                : 'Tus referencias de pareja ya están reparadas.',
          ),
        ),
      );
    } on CoupleException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFFF7EB3), Color(0xFFFFB199)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    if (canGoBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(height: 48),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Conéctate con tu pareja ❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Crea un código para compartirlo o escribe el código que te enviaron.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 35),
                _bigButton(
                  text: isLoading
                      ? 'Cargando...'
                      : generatedCode.isEmpty
                      ? 'Crear Código'
                      : 'Generar nuevo Código',
                  color: const Color(0xFF4CAF50),
                  onTap: isLoading ? null : createCode,
                ),
                const SizedBox(height: 20),
                if (generatedCode.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Comparte este código con tu pareja:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          generatedCode,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Este código es válido durante 24 horas. '
                          'Si generas otro, este dejará de funcionar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                if (generatedCode.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : cancelCode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar y reiniciar código'),
                  ),
                ],
                const SizedBox(height: 25),
                const Text(
                  'o ingresa el código de tu pareja',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ABC123',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _bigButton(
                  text: isLoading ? 'Cargando...' : 'Unirse con Código',
                  color: Colors.orange,
                  onTap: isLoading ? null : joinCode,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: isLoading ? null : repairConnection,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Reparar una conexión anterior'),
                ),
                const SizedBox(height: 35),
                const Text(
                  '¡Jueguen juntos y cuiden su mascota! 🐶❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String text,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
