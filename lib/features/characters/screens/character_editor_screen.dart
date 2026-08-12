import 'package:flutter/material.dart';

import '../../profile/services/profile_service.dart';
import '../models/character_appearance.dart';
import '../widgets/character_appearance_preview.dart';

class CharacterEditorScreen extends StatefulWidget {
  const CharacterEditorScreen({
    super.key,
    required this.initialAppearance,
    this.repository,
  });

  final CharacterAppearance initialAppearance;
  final CharacterAppearanceRepository? repository;

  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  late final CharacterAppearanceRepository _repository =
      widget.repository ?? ProfileService();
  late CharacterAppearance _appearance = widget.initialAppearance;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateCharacterAppearance(_appearance);
      if (mounted) Navigator.pop(context, true);
    } on ProfileException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('No se pudo guardar el personaje. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu personaje'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('character_editor'),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            Center(child: CharacterAppearancePreview(appearance: _appearance)),
            const SizedBox(height: 20),
            _choices(
              'Estilo base animado',
              CharacterBaseStyle.values,
              _appearance.baseStyle,
              _baseLabel,
              (value) => _appearance = _appearance.copyWith(baseStyle: value),
            ),
            _choices(
              'Cabello',
              CharacterHairStyle.values,
              _appearance.hairStyle,
              _hairStyleLabel,
              (value) => _appearance = _appearance.copyWith(hairStyle: value),
            ),
            _choices(
              'Color de cabello',
              CharacterHairColor.values,
              _appearance.hairColor,
              _hairColorLabel,
              (value) => _appearance = _appearance.copyWith(hairColor: value),
            ),
            _choices(
              'Tono de piel',
              CharacterSkinTone.values,
              _appearance.skinTone,
              _skinLabel,
              (value) => _appearance = _appearance.copyWith(skinTone: value),
            ),
            _choices(
              'Ropa',
              CharacterOutfitStyle.values,
              _appearance.outfitStyle,
              _outfitLabel,
              (value) => _appearance = _appearance.copyWith(outfitStyle: value),
            ),
            _choices(
              'Color de ropa',
              CharacterOutfitColor.values,
              _appearance.outfitColor,
              _outfitColorLabel,
              (value) => _appearance = _appearance.copyWith(outfitColor: value),
            ),
            _choices(
              'Calzado',
              CharacterShoes.values,
              _appearance.shoes,
              _shoesLabel,
              (value) => _appearance = _appearance.copyWith(shoes: value),
            ),
            _choices(
              'Accesorio',
              CharacterAccessory.values,
              _appearance.accessory,
              _accessoryLabel,
              (value) => _appearance = _appearance.copyWith(accessory: value),
            ),
            _choices(
              'Expresión',
              CharacterExpression.values,
              _appearance.expression,
              _expressionLabel,
              (value) => _appearance = _appearance.copyWith(expression: value),
            ),
            _choices(
              'Pose',
              CharacterPose.values,
              _appearance.pose,
              _poseLabel,
              (value) => _appearance = _appearance.copyWith(pose: value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Guardando…' : 'Guardar personaje'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choices<T extends Enum>(
    String title,
    List<T> values,
    T selected,
    String Function(T) label,
    void Function(T) update,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              return ChoiceChip(
                label: Text(label(value)),
                selected: selected == value,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => update(value)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

String _baseLabel(CharacterBaseStyle value) => switch (value) {
  CharacterBaseStyle.classicBoy => 'Clásico A',
  CharacterBaseStyle.classicGirl => 'Clásico B',
};

String _hairStyleLabel(CharacterHairStyle value) => switch (value) {
  CharacterHairStyle.short => 'Corto',
  CharacterHairStyle.long => 'Largo',
  CharacterHairStyle.curls => 'Rizos',
};

String _hairColorLabel(CharacterHairColor value) => switch (value) {
  CharacterHairColor.brown => 'Castaño',
  CharacterHairColor.black => 'Negro',
  CharacterHairColor.blonde => 'Rubio',
  CharacterHairColor.copper => 'Cobrizo',
};

String _skinLabel(CharacterSkinTone value) => switch (value) {
  CharacterSkinTone.light => 'Claro',
  CharacterSkinTone.warm => 'Cálido',
  CharacterSkinTone.deep => 'Profundo',
};

String _outfitLabel(CharacterOutfitStyle value) => switch (value) {
  CharacterOutfitStyle.casual => 'Casual',
  CharacterOutfitStyle.cozy => 'Cómoda',
  CharacterOutfitStyle.elegant => 'Elegante',
};

String _outfitColorLabel(CharacterOutfitColor value) => switch (value) {
  CharacterOutfitColor.rose => 'Rosa',
  CharacterOutfitColor.plum => 'Ciruela',
  CharacterOutfitColor.blue => 'Azul',
  CharacterOutfitColor.green => 'Verde',
};

String _shoesLabel(CharacterShoes value) => switch (value) {
  CharacterShoes.sneakers => 'Zapatillas',
  CharacterShoes.boots => 'Botas',
};

String _accessoryLabel(CharacterAccessory value) => switch (value) {
  CharacterAccessory.none => 'Ninguno',
  CharacterAccessory.glasses => 'Lentes',
  CharacterAccessory.heartPin => 'Corazón',
  CharacterAccessory.headband => 'Vincha',
};

String _expressionLabel(CharacterExpression value) => switch (value) {
  CharacterExpression.smile => 'Sonrisa',
  CharacterExpression.calm => 'Calma',
  CharacterExpression.excited => 'Emoción',
};

String _poseLabel(CharacterPose value) => switch (value) {
  CharacterPose.idle => 'De pie',
  CharacterPose.wave => 'Saludando',
  CharacterPose.sit => 'Sentado',
};
