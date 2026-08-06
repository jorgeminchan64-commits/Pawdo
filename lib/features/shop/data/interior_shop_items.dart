import 'package:flame/components.dart';

class InteriorShopItem {
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

  InteriorShopItem({
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
}

final List<InteriorShopItem> interiorShopItems = [
  InteriorShopItem(
    id: 'bed_romantic',
    name: 'Cama Romántica',
    description: 'Cama elegante en tonos rosados para descansar juntos.',
    type: 'bed',
    assetPath: 'interior/bed_romantic.png',
    size: Vector2(360, 230),
    price: 700,
    currency: 'coins',
    emoji: '🛏️',
  ),
  InteriorShopItem(
    id: 'sofa_romantic',
    name: 'Sofá Romántico',
    description: 'Sofá pastel cómodo para sentarse en pareja.',
    type: 'sofa',
    assetPath: 'interior/sofa_romantic.png',
    size: Vector2(390, 245),
    price: 450,
    currency: 'coins',
    emoji: '🛋️',
  ),
  InteriorShopItem(
    id: 'table_romantic',
    name: 'Mesa Romántica',
    description: 'Mesa bonita para comer juntos y ganar recompensas.',
    type: 'table',
    assetPath: 'interior/table_romantic.png',
    size: Vector2(335, 185),
    price: 350,
    currency: 'coins',
    emoji: '🍽️',
  ),
  InteriorShopItem(
    id: 'tv_stand_romantic',
    name: 'Mueble TV',
    description: 'Mueble pastel con TV para ver películas juntos.',
    type: 'tv',
    assetPath: 'interior/tv_stand_romantic.png',
    size: Vector2(360, 230),
    price: 400,
    currency: 'coins',
    emoji: '📺',
  ),
  InteriorShopItem(
    id: 'plant_inside',
    name: 'Planta Interior',
    description: 'Planta decorativa para dar vida al interior.',
    type: 'plant',
    assetPath: 'interior/plant_inside.png',
    size: Vector2(165, 195),
    price: 120,
    currency: 'coins',
    emoji: '🪴',
  ),
  InteriorShopItem(
    id: 'lamp_romantic',
    name: 'Lámpara Romántica',
    description: 'Lámpara elegante en tonos pastel y dorados.',
    type: 'lamp',
    assetPath: 'interior/lamp_romantic.png',
    size: Vector2(130, 235),
    price: 180,
    currency: 'coins',
    emoji: '💡',
  ),
  InteriorShopItem(
    id: 'rug_pink',
    name: 'Alfombra Rosa',
    description: 'Alfombra decorativa para hacer el cuarto más cálido.',
    type: 'rug',
    assetPath: 'interior/rug_pink.png',
    size: Vector2(430, 155),
    price: 160,
    currency: 'coins',
    emoji: '🟣',
  ),
  InteriorShopItem(
    id: 'pet_bed_inside',
    name: 'Cama Pawdo',
    description: 'Camita de lujo para que Pawdo descanse feliz.',
    type: 'pet_bed',
    assetPath: 'interior/pet_bed_inside.png',
    size: Vector2(180, 120),
    price: 250,
    currency: 'coins',
    emoji: '🐶',
  ),
];

InteriorShopItem? findInteriorShopItemById(String id) {
  for (final item in interiorShopItems) {
    if (item.id == id) return item;
  }

  return null;
}
