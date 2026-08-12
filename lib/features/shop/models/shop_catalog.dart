enum ShopAccess { free, coins, locked, premiumFuture }

enum ShopDestination { character, interior, garden, profile, unavailable }

class ShopCategoryEntry {
  const ShopCategoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.access,
    required this.destination,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final ShopAccess access;
  final ShopDestination destination;

  bool get canOpen => destination != ShopDestination.unavailable;
}

const shopCatalog = <ShopCategoryEntry>[
  ShopCategoryEntry(
    id: 'clothing',
    title: 'Ropa',
    subtitle: 'Combina el estilo de tu personaje.',
    emoji: '👕',
    access: ShopAccess.free,
    destination: ShopDestination.character,
  ),
  ShopCategoryEntry(
    id: 'hair',
    title: 'Cabello',
    subtitle: 'Elige peinado y color.',
    emoji: '💇',
    access: ShopAccess.free,
    destination: ShopDestination.character,
  ),
  ShopCategoryEntry(
    id: 'accessories',
    title: 'Accesorios',
    subtitle: 'Añade un detalle personal.',
    emoji: '🎀',
    access: ShopAccess.free,
    destination: ShopDestination.character,
  ),
  ShopCategoryEntry(
    id: 'shoes',
    title: 'Zapatos',
    subtitle: 'Completa tu conjunto.',
    emoji: '👟',
    access: ShopAccess.free,
    destination: ShopDestination.character,
  ),
  ShopCategoryEntry(
    id: 'decoration',
    title: 'Decoración',
    subtitle: 'Objetos para su espacio compartido.',
    emoji: '🪴',
    access: ShopAccess.coins,
    destination: ShopDestination.interior,
  ),
  ShopCategoryEntry(
    id: 'furniture',
    title: 'Muebles',
    subtitle: 'Cama, sofá, mesa y más.',
    emoji: '🛋️',
    access: ShopAccess.coins,
    destination: ShopDestination.interior,
  ),
  ShopCategoryEntry(
    id: 'garden',
    title: 'Jardín',
    subtitle: 'Flores, árboles y casas.',
    emoji: '🌷',
    access: ShopAccess.coins,
    destination: ShopDestination.garden,
  ),
  ShopCategoryEntry(
    id: 'pet',
    title: 'Mascota',
    subtitle: 'Nuevos estilos para Pawdo.',
    emoji: '🐾',
    access: ShopAccess.locked,
    destination: ShopDestination.unavailable,
  ),
  ShopCategoryEntry(
    id: 'backgrounds',
    title: 'Fondos',
    subtitle: 'Personaliza la portada del perfil.',
    emoji: '🌅',
    access: ShopAccess.free,
    destination: ShopDestination.profile,
  ),
  ShopCategoryEntry(
    id: 'themes',
    title: 'Temas',
    subtitle: 'Rosa, lavanda o atardecer.',
    emoji: '🎨',
    access: ShopAccess.free,
    destination: ShopDestination.profile,
  ),
];
