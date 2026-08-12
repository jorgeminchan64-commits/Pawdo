enum CharacterBaseStyle { classicBoy, classicGirl }

enum CharacterHairStyle { short, long, curls }

enum CharacterHairColor { brown, black, blonde, copper }

enum CharacterSkinTone { light, warm, deep }

enum CharacterOutfitStyle { casual, cozy, elegant }

enum CharacterOutfitColor { rose, plum, blue, green }

enum CharacterShoes { sneakers, boots }

enum CharacterAccessory { none, glasses, heartPin, headband }

enum CharacterExpression { smile, calm, excited }

enum CharacterPose { idle, wave, sit }

class CharacterAppearance {
  const CharacterAppearance({
    this.baseStyle = CharacterBaseStyle.classicBoy,
    this.hairStyle = CharacterHairStyle.short,
    this.hairColor = CharacterHairColor.brown,
    this.skinTone = CharacterSkinTone.warm,
    this.outfitStyle = CharacterOutfitStyle.casual,
    this.outfitColor = CharacterOutfitColor.rose,
    this.shoes = CharacterShoes.sneakers,
    this.accessory = CharacterAccessory.none,
    this.expression = CharacterExpression.smile,
    this.pose = CharacterPose.idle,
  });

  factory CharacterAppearance.fromMap(dynamic value) {
    if (value is! Map) return const CharacterAppearance();
    return CharacterAppearance(
      baseStyle: _enumValue(
        CharacterBaseStyle.values,
        value['baseStyle'],
        CharacterBaseStyle.classicBoy,
      ),
      hairStyle: _enumValue(
        CharacterHairStyle.values,
        value['hairStyle'],
        CharacterHairStyle.short,
      ),
      hairColor: _enumValue(
        CharacterHairColor.values,
        value['hairColor'],
        CharacterHairColor.brown,
      ),
      skinTone: _enumValue(
        CharacterSkinTone.values,
        value['skinTone'],
        CharacterSkinTone.warm,
      ),
      outfitStyle: _enumValue(
        CharacterOutfitStyle.values,
        value['outfitStyle'],
        CharacterOutfitStyle.casual,
      ),
      outfitColor: _enumValue(
        CharacterOutfitColor.values,
        value['outfitColor'],
        CharacterOutfitColor.rose,
      ),
      shoes: _enumValue(
        CharacterShoes.values,
        value['shoes'],
        CharacterShoes.sneakers,
      ),
      accessory: _enumValue(
        CharacterAccessory.values,
        value['accessory'],
        CharacterAccessory.none,
      ),
      expression: _enumValue(
        CharacterExpression.values,
        value['expression'],
        CharacterExpression.smile,
      ),
      pose: _enumValue(CharacterPose.values, value['pose'], CharacterPose.idle),
    );
  }

  final CharacterBaseStyle baseStyle;
  final CharacterHairStyle hairStyle;
  final CharacterHairColor hairColor;
  final CharacterSkinTone skinTone;
  final CharacterOutfitStyle outfitStyle;
  final CharacterOutfitColor outfitColor;
  final CharacterShoes shoes;
  final CharacterAccessory accessory;
  final CharacterExpression expression;
  final CharacterPose pose;

  Map<String, String> toMap() => {
    'baseStyle': baseStyle.name,
    'hairStyle': hairStyle.name,
    'hairColor': hairColor.name,
    'skinTone': skinTone.name,
    'outfitStyle': outfitStyle.name,
    'outfitColor': outfitColor.name,
    'shoes': shoes.name,
    'accessory': accessory.name,
    'expression': expression.name,
    'pose': pose.name,
  };

  CharacterAppearance copyWith({
    CharacterBaseStyle? baseStyle,
    CharacterHairStyle? hairStyle,
    CharacterHairColor? hairColor,
    CharacterSkinTone? skinTone,
    CharacterOutfitStyle? outfitStyle,
    CharacterOutfitColor? outfitColor,
    CharacterShoes? shoes,
    CharacterAccessory? accessory,
    CharacterExpression? expression,
    CharacterPose? pose,
  }) {
    return CharacterAppearance(
      baseStyle: baseStyle ?? this.baseStyle,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      skinTone: skinTone ?? this.skinTone,
      outfitStyle: outfitStyle ?? this.outfitStyle,
      outfitColor: outfitColor ?? this.outfitColor,
      shoes: shoes ?? this.shoes,
      accessory: accessory ?? this.accessory,
      expression: expression ?? this.expression,
      pose: pose ?? this.pose,
    );
  }

  static T _enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) {
    final name = raw?.toString();
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
