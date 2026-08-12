import 'dart:math';

enum CoupleCardMode { trivia, trueOrFalse, chooseOne }

class CoupleCard {
  const CoupleCard({required this.prompt, required this.options});
  final String prompt;
  final List<String> options;
}

class CoupleCardDeck {
  CoupleCardDeck(this.mode, {int? seed}) : _random = Random(seed);
  final CoupleCardMode mode;
  final Random _random;
  int _lastIndex = -1;

  List<CoupleCard> get cards => switch (mode) {
    CoupleCardMode.trivia => _trivia,
    CoupleCardMode.trueOrFalse => _trueOrFalse,
    CoupleCardMode.chooseOne => _chooseOne,
  };

  CoupleCard next() {
    if (cards.length == 1) return cards.first;
    var index = _random.nextInt(cards.length);
    while (index == _lastIndex) {
      index = _random.nextInt(cards.length);
    }
    _lastIndex = index;
    return cards[index];
  }
}

const _trivia = [
  CoupleCard(
    prompt: '¿Cuál fue nuestra primera salida?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
  CoupleCard(
    prompt: '¿Qué comida pediría mi pareja hoy?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
  CoupleCard(
    prompt: '¿Qué canción representa mejor nuestra historia?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
  CoupleCard(
    prompt: '¿Cuál es el sueño que más quiere cumplir?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
  CoupleCard(
    prompt: '¿Qué detalle pequeño le hace sonreír?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
  CoupleCard(
    prompt: '¿Cuál es su película favorita para repetir?',
    options: ['Yo respondo', 'Mi pareja responde'],
  ),
];

const _trueOrFalse = [
  CoupleCard(
    prompt: 'Prefiero una cita en casa que una fiesta grande.',
    options: ['Verdadero', 'Falso'],
  ),
  CoupleCard(
    prompt: 'Me gustaría viajar contigo sin un itinerario estricto.',
    options: ['Verdadero', 'Falso'],
  ),
  CoupleCard(
    prompt: 'Un abrazo me ayuda más que un consejo inmediato.',
    options: ['Verdadero', 'Falso'],
  ),
  CoupleCard(
    prompt: 'Me emociona planear nuestro próximo aniversario.',
    options: ['Verdadero', 'Falso'],
  ),
  CoupleCard(
    prompt: 'Prefiero recibir una nota escrita que un regalo costoso.',
    options: ['Verdadero', 'Falso'],
  ),
  CoupleCard(
    prompt: 'Me gustaría aprender una actividad nueva contigo.',
    options: ['Verdadero', 'Falso'],
  ),
];

const _chooseOne = [
  CoupleCard(
    prompt: 'Elige una cita',
    options: ['Picnic al atardecer', 'Película en casa'],
  ),
  CoupleCard(
    prompt: 'Elige un viaje',
    options: ['Playa tranquila', 'Montaña y aventura'],
  ),
  CoupleCard(
    prompt: 'Elige un detalle',
    options: ['Carta sorpresa', 'Desayuno favorito'],
  ),
  CoupleCard(
    prompt: 'Elige un plan',
    options: ['Cocinar juntos', 'Salir a caminar'],
  ),
  CoupleCard(
    prompt: 'Elige un recuerdo',
    options: ['Recrear una foto', 'Volver a la primera cita'],
  ),
  CoupleCard(
    prompt: 'Elige una noche',
    options: ['Juegos y risas', 'Música y conversación'],
  ),
];
