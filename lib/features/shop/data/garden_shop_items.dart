import 'package:flame/components.dart';

class GardenShopItem {
  final String id;
  final String name;
  final String description;
  final String type;
  final String assetPath;
  final Vector2 size;
  final int price;
  final String currency;
  final String emoji;
  final bool comingSoonPremium;
  final String? realMoneyProductId;

  GardenShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.assetPath,
    required this.size,
    required this.price,
    required this.currency,
    required this.emoji,
    this.comingSoonPremium = false,
    this.realMoneyProductId,
  });

  bool get isFree => price <= 0 && currency == 'coins';
  bool get isCoins => currency == 'coins';
  bool get isRealMoney => currency == 'real_money';
  bool get isHouse => type == 'house';
  bool get isDecoration => type != 'house';
}

final List<GardenShopItem> gardenShopItems = [
  // =========================
  // DECORACIÓN DEL JARDÍN
  // =========================
  GardenShopItem(
    id: 'flower_pot_pink',
    name: 'Maceta Rosa',
    description: 'Una maceta dulce para decorar rincones del jardín.',
    type: 'pot',
    assetPath: 'garden/flower_pot_pink.png',
    size: Vector2(105, 105),
    price: 30,
    currency: 'coins',
    emoji: '🌸',
  ),
  GardenShopItem(
    id: 'flower_bed_large',
    name: 'Flores Grandes',
    description: 'Un bloque de flores coloridas para dar vida al jardín.',
    type: 'flowers',
    assetPath: 'garden/flower_bed_large.png',
    size: Vector2(320, 125),
    price: 60,
    currency: 'coins',
    emoji: '🌼',
  ),
  GardenShopItem(
    id: 'flower_box_long',
    name: 'Jardinera Larga',
    description: 'Perfecta para bordes y caminos románticos.',
    type: 'flowers',
    assetPath: 'garden/flower_box_long.png',
    size: Vector2(355, 118),
    price: 80,
    currency: 'coins',
    emoji: '🌷',
  ),
  GardenShopItem(
    id: 'bush_flowers',
    name: 'Arbusto Floral',
    description: 'Arbusto decorativo con flores suaves.',
    type: 'bush',
    assetPath: 'garden/bush_flowers.png',
    size: Vector2(205, 115),
    price: 90,
    currency: 'coins',
    emoji: '🌿',
  ),
  GardenShopItem(
    id: 'tree_flower_small',
    name: 'Árbol Pequeño',
    description: 'Un árbol pequeño y bonito para rellenar espacios.',
    type: 'tree',
    assetPath: 'garden/tree_flower_small.png',
    size: Vector2(155, 155),
    price: 120,
    currency: 'coins',
    emoji: '🌳',
  ),
  GardenShopItem(
    id: 'apple_tree',
    name: 'Manzano',
    description: 'Árbol frutal para un jardín más vivo.',
    type: 'tree',
    assetPath: 'garden/apple_tree.png',
    size: Vector2(275, 275),
    price: 180,
    currency: 'coins',
    emoji: '🍎',
  ),
  GardenShopItem(
    id: 'tree_big_love',
    name: 'Árbol Amor',
    description: 'Árbol grande para dar sombra y estilo.',
    type: 'tree',
    assetPath: 'garden/tree_big_love.png',
    size: Vector2(330, 330),
    price: 250,
    currency: 'coins',
    emoji: '💖',
  ),
  GardenShopItem(
    id: 'plant_special_love',
    name: 'Planta Especial',
    description: 'Una planta romántica para momentos especiales.',
    type: 'special_plant',
    assetPath: 'garden/plant_special_love.png',
    size: Vector2(118, 92),
    price: 150,
    currency: 'coins',
    emoji: '✨',
  ),
  GardenShopItem(
    id: 'table_garden',
    name: 'Mesa Romántica',
    description: 'Mesa para acciones de pareja en el jardín.',
    type: 'table',
    assetPath: 'garden/table_garden.png',
    size: Vector2(205, 130),
    price: 220,
    currency: 'coins',
    emoji: '🪑',
  ),

  // =========================
  // CASAS CON MONEDAS
  // =========================
  GardenShopItem(
    id: 'house_basic1',
    name: 'Casa Básica',
    description: 'La casita inicial de Pawdo. Gratis para todos.',
    type: 'house',
    assetPath: 'houses/house_basic1.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'coins',
    emoji: '🏡',
  ),

  GardenShopItem(
    id: 'house_basic',
    name: 'Casa Básica',
    description: 'La casita inicial de Pawdo. Gratis para todos.',
    type: 'house',
    assetPath: 'houses/house_basic.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'coins',
    emoji: '🏡',
  ),
  GardenShopItem(
    id: 'house_garden_cozy',
    name: 'Casa Jardín Cozy',
    description: 'Una casita acogedora con flores y encanto natural.',
    type: 'house',
    assetPath: 'houses/house_garden_cozy.png',
    size: Vector2(440, 440),
    price: 500,
    currency: 'coins',
    emoji: '🌷',
  ),
  GardenShopItem(
    id: 'house_romantic',
    name: 'Casa Romántica',
    description: 'Una casa especial para parejas, con detalles de corazones.',
    type: 'house',
    assetPath: 'houses/house_romantic.png',
    size: Vector2(440, 440),
    price: 1200,
    currency: 'coins',
    emoji: '💖',
  ),
  GardenShopItem(
    id: 'house_blossom',
    name: 'Casa Blossom',
    description: 'Casa primaveral llena de flores suaves y colores pastel.',
    type: 'house',
    assetPath: 'houses/house_blossom.png',
    size: Vector2(440, 440),
    price: 1600,
    currency: 'coins',
    emoji: '🌸',
  ),
  GardenShopItem(
    id: 'house_sunset_cottage',
    name: 'Casa Sunset Cottage',
    description: 'Un cottage cálido con tonos de atardecer y ambiente dulce.',
    type: 'house',
    assetPath: 'houses/house_sunset_cottage.png',
    size: Vector2(440, 440),
    price: 2000,
    currency: 'coins',
    emoji: '🌅',
  ),
  GardenShopItem(
    id: 'house_modern_love',
    name: 'Casa Modern Love',
    description: 'Casa moderna, elegante y romántica en tonos crema y rosa.',
    type: 'house',
    assetPath: 'houses/house_modern_love.png',
    size: Vector2(440, 440),
    price: 2600,
    currency: 'coins',
    emoji: '🏠',
  ),

  // =========================
  // PREMIUM PRÓXIMAMENTE
  // =========================
  GardenShopItem(
    id: 'house_fairy_dream',
    name: 'Casa Fairy Dream',
    description: 'Casa mágica de cuento con luces, flores y fantasía.',
    type: 'house',
    assetPath: 'houses/house_fairy_dream.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'real_money',
    emoji: '🧚',
    comingSoonPremium: true,
    realMoneyProductId: 'house_fairy_dream_001',
  ),
  GardenShopItem(
    id: 'house_sakura_premium',
    name: 'Casa Sakura Premium',
    description: 'Casa premium estilo sakura, romántica y exclusiva.',
    type: 'house',
    assetPath: 'houses/house_sakura_premium.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'real_money',
    emoji: '🌸',
    comingSoonPremium: true,
    realMoneyProductId: 'house_sakura_premium_001',
  ),
  GardenShopItem(
    id: 'house_royal_pink',
    name: 'Casa Royal Pink',
    description: 'Mansión rosa de lujo para parejas top.',
    type: 'house',
    assetPath: 'houses/house_royal_pink.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'real_money',
    emoji: '👑',
    comingSoonPremium: true,
    realMoneyProductId: 'house_royal_pink_001',
  ),
  GardenShopItem(
    id: 'house_moonlight_premium',
    name: 'Casa Moonlight',
    description: 'Casa premium nocturna con tonos lunares y magia suave.',
    type: 'house',
    assetPath: 'houses/house_moonlight_premium.png',
    size: Vector2(440, 440),
    price: 0,
    currency: 'real_money',
    emoji: '🌙',
    comingSoonPremium: true,
    realMoneyProductId: 'house_moonlight_premium_001',
  ),
];

GardenShopItem? findGardenShopItemById(String id) {
  for (final item in gardenShopItems) {
    if (item.id == id) return item;
  }

  return null;
}
