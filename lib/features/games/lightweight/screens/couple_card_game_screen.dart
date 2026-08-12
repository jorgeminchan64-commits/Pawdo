import 'package:flutter/material.dart';

import '../models/couple_card_deck.dart';

class CoupleCardGameScreen extends StatefulWidget {
  const CoupleCardGameScreen({super.key, required this.mode});
  final CoupleCardMode mode;
  @override
  State<CoupleCardGameScreen> createState() => _CoupleCardGameScreenState();
}

class _CoupleCardGameScreenState extends State<CoupleCardGameScreen> {
  late final CoupleCardDeck _deck = CoupleCardDeck(widget.mode);
  late CoupleCard _card = _deck.next();
  String? _choice;

  String get _title => switch (widget.mode) {
    CoupleCardMode.trivia => '¿Quién conoce mejor?',
    CoupleCardMode.trueOrFalse => 'Verdadero o falso',
    CoupleCardMode.chooseOne => 'Elige uno',
  };

  void _next() => setState(() {
    _card = _deck.next();
    _choice = null;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Text(
              'Jueguen juntos en este teléfono · sin puntos ni presión',
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Card(
                key: ValueKey(_card.prompt),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Text('💞', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 14),
                      Text(
                        _card.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (final option in _card.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () => setState(() => _choice = option),
                              child: Text(option),
                            ),
                          ),
                        ),
                      if (_choice != null)
                        Text(
                          'Elegiste: $_choice. Ahora escucha la respuesta de tu pareja.',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.navigate_next_rounded),
              label: const Text('Siguiente tarjeta'),
            ),
          ],
        ),
      ),
    ),
  );
}
