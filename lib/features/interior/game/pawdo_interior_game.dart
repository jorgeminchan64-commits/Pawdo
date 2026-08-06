import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../world/components/actors/animated_actor_component.dart';
import '../../world/components/depth_priority.dart';
import '../components/editable_interior_item.dart';

enum InteriorDeleteResult { deleted, noSelection, protected }

class PawdoInteriorGame extends FlameGame with TapCallbacks, DragCallbacks {
  PawdoInteriorGame({
    required this.onInteriorReward,
    required this.onOpenCinema,
    required this.onOpenGames,
  });

  final Future<void> Function(Map<String, dynamic> reward) onInteriorReward;
  final VoidCallback onOpenCinema;
  final VoidCallback onOpenGames;

  static const double roomWidth = 1800;
  static const double roomHeight = 900;
  static const Set<String> starterItemIds = {
    'bed_01',
    'sofa_01',
    'table_01',
    'tv_01',
    'plant_01',
    'lamp_01',
    'rug_01',
    'pet_bed_01',
  };

  final math.Random _random = math.Random();

  late AnimatedActorComponent boy;
  late AnimatedActorComponent girl;
  late AnimatedActorComponent dog;

  bool isInteriorEditMode = false;
  bool _actionRunning = false;
  double _dogTimer = 0;

  final List<EditableInteriorItem> furnitureItems = [];
  EditableInteriorItem? selectedInteriorItem;

  Set<String> get placedCatalogItemIds => furnitureItems
      .map((item) => item.catalogItemId)
      .whereType<String>()
      .toSet();

  final Rect walkableArea = const Rect.fromLTWH(330, 470, 1140, 320);
  final Rect gamesZone = const Rect.fromLTWH(1340, 140, 150, 100);
  @override
  Color backgroundColor() => const Color(0xFFFFEEF5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(roomWidth / 2, 470);

    await _loadInterior();
  }

  Future<void> _loadInterior() async {
    await _addRoomBackground();
    await _addFixedGamesPortal();
    await _addDefaultFurniture();
    await _addActors();
  }

  Future<void> _addFixedGamesPortal() async {
    final image = await images.load('interior/games_portal.png');

    world.add(
      SpriteComponent(
        sprite: Sprite(image),
        position: Vector2(1415, 205),
        size: Vector2(155, 95),
        anchor: Anchor.center,
        priority: 30,
      ),
    );
  }

  Future<void> _addRoomBackground() async {
    final roomImage = await images.load('interior/background_room_pastel.png');

    world.add(
      SpriteComponent(
        sprite: Sprite(roomImage),
        position: Vector2.zero(),
        size: Vector2(roomWidth, roomHeight),
        anchor: Anchor.topLeft,
        priority: sceneDepthPriority(
          layer: SceneDepthLayer.background,
          baselineY: 0,
        ),
      ),
    );
  }

  Future<void> _addActors() async {
    final boySheet = await images.load(
      'avatars/avatar_boy_pro_spritesheet.png',
    );

    boy = AnimatedActorComponent(
      spriteSheet: boySheet,
      startPosition: Vector2(1030, 705),
      size: Vector2(150, 265),
      spriteLayout: ActorSpriteLayout.boy,
      depthTieBreaker: 1,
      speed: 155,
      anchor: Anchor.bottomCenter,
    );
    world.add(boy);

    final girlSheet = await images.load(
      'avatars/avatar_girl_pro_spritesheet.png',
    );

    girl = AnimatedActorComponent(
      spriteSheet: girlSheet,
      startPosition: Vector2(1160, 705),
      size: Vector2(150, 265),
      spriteLayout: ActorSpriteLayout.girl,
      depthTieBreaker: 2,
      speed: 155,
      anchor: Anchor.bottomCenter,
    );
    world.add(girl);

    final dogSheet = await images.load('pets/dog_pro_spritesheet.png');

    dog = AnimatedActorComponent(
      spriteSheet: dogSheet,
      startPosition: Vector2(920, 775),
      size: Vector2(120, 120),
      spriteLayout: ActorSpriteLayout.dog,
      depthTieBreaker: 3,
      speed: 205,
      anchor: Anchor.bottomCenter,
    );
    world.add(dog);
  }

  Future<void> _addDefaultFurniture() async {
    await _addFurnitureItem(
      id: 'bed_01',
      type: 'bed',
      label: 'Cama',
      assetPath: _assetForFurnitureType('bed'),
      position: Vector2(420, 650),
      size: Vector2(360, 230),
      priority: 650,
    );

    await _addFurnitureItem(
      id: 'sofa_01',
      type: 'sofa',
      label: 'Sofá',
      assetPath: _assetForFurnitureType('sofa'),
      position: Vector2(820, 640),
      size: Vector2(390, 245),
      priority: 640,
    );

    await _addFurnitureItem(
      id: 'table_01',
      type: 'table',
      label: 'Mesa',
      assetPath: _assetForFurnitureType('table'),
      position: Vector2(690, 745),
      size: Vector2(335, 185),
      priority: 745,
    );

    await _addFurnitureItem(
      id: 'tv_01',
      type: 'tv',
      label: 'TV',
      assetPath: _assetForFurnitureType('tv'),
      position: Vector2(370, 575),
      size: Vector2(360, 230),
      priority: 575,
    );

    await _addFurnitureItem(
      id: 'plant_01',
      type: 'plant',
      label: 'Planta',
      assetPath: _assetForFurnitureType('plant'),
      position: Vector2(1240, 640),
      size: Vector2(165, 195),
      priority: 640,
    );

    await _addFurnitureItem(
      id: 'lamp_01',
      type: 'lamp',
      label: 'Lámpara',
      assetPath: _assetForFurnitureType('lamp'),
      position: Vector2(1120, 630),
      size: Vector2(130, 235),
      priority: 630,
    );

    await _addFurnitureItem(
      id: 'rug_01',
      type: 'rug',
      label: 'Alfombra',
      assetPath: _assetForFurnitureType('rug'),
      position: Vector2(760, 805),
      size: Vector2(430, 155),
      priority: 505,
    );

    await _addFurnitureItem(
      id: 'pet_bed_01',
      type: 'pet_bed',
      label: 'Cama Pawdo',
      assetPath: _assetForFurnitureType('pet_bed'),
      position: Vector2(1370, 745),
      size: Vector2(180, 120),
      priority: 745,
    );
  }

  Future<EditableInteriorItem> _addFurnitureItem({
    required String id,
    required String type,
    required String label,
    required String assetPath,
    required Vector2 position,
    required Vector2 size,
    required int priority,
    String? catalogItemId,
    bool? isSystemItem,
    bool? deletable,
  }) async {
    final image = await images.load(assetPath);

    final item = EditableInteriorItem(
      itemId: id,
      itemType: type,
      label: label,
      assetPath: assetPath,
      catalogItemId: catalogItemId,
      isSystemItem: isSystemItem ?? starterItemIds.contains(id),
      deletable: deletable,
      sprite: Sprite(image),
      position: position,
      size: size,
      priority: priority,
    );

    furnitureItems.add(item);
    world.add(item);

    return item;
  }

  void setInteriorEditMode(bool value) {
    isInteriorEditMode = value;

    if (!value) {
      _clearSelectedInteriorItem();
    }
  }

  List<Map<String, dynamic>> exportInteriorLayout() {
    return furnitureItems.map((item) => item.toJson()).toList();
  }

  Future<void> loadInteriorLayout(List<dynamic> layout) async {
    if (furnitureItems.isEmpty) return;

    final savedIds = <String>{};

    for (final rawItem in layout) {
      if (rawItem is! Map) continue;

      final id = rawItem['id']?.toString();
      final type = rawItem['type']?.toString();

      if (id == null || type == null) continue;
      final catalogIdForType = _catalogItemIdForType(type);
      if (catalogIdForType == null) continue;

      final expectedAssetPath = _assetForFurnitureType(type);
      final savedAssetPath = rawItem['assetPath']?.toString();
      if (savedAssetPath != null && savedAssetPath != expectedAssetPath) {
        continue;
      }
      final savedCatalogItemId = rawItem['catalogItemId']?.toString();
      if (savedCatalogItemId != null &&
          savedCatalogItemId != catalogIdForType) {
        continue;
      }

      final existing = _findFurnitureById(id);
      final isSystemItem =
          starterItemIds.contains(id) || rawItem['isSystemItem'] == true;
      final catalogItemId = isSystemItem
          ? null
          : savedCatalogItemId ?? catalogIdForType;

      if (catalogItemId != null &&
          furnitureItems.any(
            (item) => item.itemId != id && item.catalogItemId == catalogItemId,
          )) {
        continue;
      }

      savedIds.add(id);

      final x = rawItem['x'];
      final y = rawItem['y'];
      final width = rawItem['width'];
      final height = rawItem['height'];
      final priority = rawItem['priority'];

      final requestedPosition = Vector2(
        x is num ? x.toDouble() : 900,
        y is num ? y.toDouble() : 650,
      );

      final size = Vector2(
        width is num ? width.toDouble() : _sizeForFurnitureType(type).x,
        height is num ? height.toDouble() : _sizeForFurnitureType(type).y,
      );
      final position = _clampItemPosition(requestedPosition, size);

      final label =
          rawItem['label']?.toString() ?? _labelForFurnitureType(type);

      final assetPath = expectedAssetPath;

      final itemPriority = priority is num
          ? priority.toInt()
          : position.y.toInt();

      if (existing != null) {
        existing.position = position;
        existing.size = size;
        existing.priority = itemPriority;
      } else {
        await _addFurnitureItem(
          id: id,
          type: type,
          label: label,
          assetPath: assetPath,
          position: position,
          size: size,
          priority: itemPriority,
          catalogItemId: catalogItemId,
          isSystemItem: isSystemItem,
          deletable: isSystemItem ? false : rawItem['deletable'] != false,
        );
      }
    }

    for (final item in List<EditableInteriorItem>.from(furnitureItems)) {
      if (!savedIds.contains(item.itemId) && !item.isSystemItem) {
        item.removeFromParent();
        furnitureItems.remove(item);
      }
    }
  }

  Future<void> addInteriorItem(String type) async {
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    final size = _sizeForFurnitureType(type);
    final position = _findAvailablePosition(type, size);

    final item = await _addFurnitureItem(
      id: id,
      type: type,
      label: _labelForFurnitureType(type),
      assetPath: _assetForFurnitureType(type),
      position: position,
      size: size,
      priority: type == 'rug' ? 505 : position.y.toInt(),
    );

    _clearSelectedInteriorItem();
    selectedInteriorItem = item;
    item.isSelected = true;
  }

  Future<bool> addInteriorItemFromShop({
    required String catalogItemId,
    required String type,
    required String label,
    required String assetPath,
    required Vector2 size,
  }) async {
    if (placedCatalogItemIds.contains(catalogItemId)) return false;

    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    final position = _findAvailablePosition(type, size);

    final item = await _addFurnitureItem(
      id: id,
      type: type,
      label: label,
      assetPath: assetPath,
      position: position,
      size: size,
      priority: type == 'rug' ? 505 : position.y.toInt(),
      catalogItemId: catalogItemId,
      isSystemItem: false,
      deletable: true,
    );

    _clearSelectedInteriorItem();
    selectedInteriorItem = item;
    item.isSelected = true;
    return true;
  }

  InteriorDeleteResult deleteSelectedInteriorItem() {
    final item = selectedInteriorItem;

    if (item == null) return InteriorDeleteResult.noSelection;
    if (!item.deletable || item.isSystemItem) {
      return InteriorDeleteResult.protected;
    }

    item.removeFromParent();
    furnitureItems.remove(item);
    selectedInteriorItem = null;

    return InteriorDeleteResult.deleted;
  }

  String? _catalogItemIdForType(String type) {
    return switch (type) {
      'bed' => 'bed_romantic',
      'sofa' => 'sofa_romantic',
      'table' => 'table_romantic',
      'tv' => 'tv_stand_romantic',
      'plant' => 'plant_inside',
      'lamp' => 'lamp_romantic',
      'rug' => 'rug_pink',
      'pet_bed' => 'pet_bed_inside',
      _ => null,
    };
  }

  EditableInteriorItem? _findFurnitureById(String id) {
    for (final item in furnitureItems) {
      if (item.itemId == id) return item;
    }

    return null;
  }

  void _clearSelectedInteriorItem() {
    for (final item in furnitureItems) {
      item.isSelected = false;
    }

    selectedInteriorItem = null;
  }

  bool _selectInteriorItem(Vector2 worldTap) {
    _clearSelectedInteriorItem();

    final item = _findFurnitureAt(worldTap);

    if (item == null) return false;

    selectedInteriorItem = item;
    item.isSelected = true;

    return true;
  }

  String _labelForFurnitureType(String type) {
    switch (type) {
      case 'bed':
        return 'Cama';
      case 'sofa':
        return 'Sofá';
      case 'table':
        return 'Mesa';
      case 'tv':
        return 'TV';
      case 'plant':
        return 'Planta';
      case 'lamp':
        return 'Lámpara';
      case 'rug':
        return 'Alfombra';
      case 'pet_bed':
        return 'Cama Pawdo';
      default:
        return 'Mueble';
    }
  }

  String _assetForFurnitureType(String type) {
    switch (type) {
      case 'bed':
        return 'interior/bed_romantic.png';
      case 'sofa':
        return 'interior/sofa_romantic.png';
      case 'table':
        return 'interior/table_romantic.png';
      case 'tv':
        return 'interior/tv_stand_romantic.png';
      case 'plant':
        return 'interior/plant_inside.png';
      case 'lamp':
        return 'interior/lamp_romantic.png';
      case 'rug':
        return 'interior/rug_pink.png';
      case 'pet_bed':
        return 'interior/pet_bed_inside.png';
      default:
        return 'interior/table_romantic.png';
    }
  }

  Vector2 _sizeForFurnitureType(String type) {
    switch (type) {
      case 'bed':
        return Vector2(410, 255);
      case 'sofa':
        return Vector2(350, 220);
      case 'table':
        return Vector2(320, 175);
      case 'tv':
        return Vector2(330, 210);
      case 'plant':
        return Vector2(175, 205);
      case 'lamp':
        return Vector2(145, 255);
      case 'rug':
        return Vector2(470, 170);
      case 'pet_bed':
        return Vector2(205, 135);
      default:
        return Vector2(180, 140);
    }
  }

  Vector2 _clampItemPosition(Vector2 position, Vector2 itemSize) {
    final halfWidth = itemSize.x / 2;
    final halfHeight = itemSize.y / 2;
    final minY = math.max(150.0, halfHeight);

    return Vector2(
      position.x.clamp(halfWidth, roomWidth - halfWidth).toDouble(),
      position.y.clamp(minY, roomHeight - halfHeight).toDouble(),
    );
  }

  Rect _placementFootprint(String type, Vector2 itemSize, Vector2 position) {
    final width = itemSize.x * 0.64;
    final height = itemSize.y * 0.28;
    return Rect.fromCenter(
      center: Offset(position.x, position.y + itemSize.y * 0.36),
      width: width,
      height: height,
    );
  }

  bool _canPlaceItem(
    String type,
    Vector2 itemSize,
    Vector2 position, {
    EditableInteriorItem? ignoredItem,
  }) {
    final candidate = _placementFootprint(type, itemSize, position);
    if (type != 'rug' && candidate.overlaps(gamesZone.inflate(18))) {
      return false;
    }

    if (type == 'rug') return true;

    for (final other in furnitureItems) {
      if (identical(other, ignoredItem) || other.itemType == 'rug') continue;
      final occupied = _placementFootprint(
        other.itemType,
        other.size,
        other.position,
      );
      if (candidate.overlaps(occupied)) return false;
    }
    return true;
  }

  Vector2 _findAvailablePosition(String type, Vector2 itemSize) {
    for (int attempt = 0; attempt < 32; attempt++) {
      final requested = Vector2(
        650 + _random.nextDouble() * 500,
        590 + _random.nextDouble() * 210,
      );
      final candidate = _clampItemPosition(requested, itemSize);
      if (_canPlaceItem(type, itemSize, candidate)) return candidate;
    }

    for (double y = 560; y <= 800; y += 55) {
      for (double x = 360; x <= 1440; x += 90) {
        final candidate = _clampItemPosition(Vector2(x, y), itemSize);
        if (_canPlaceItem(type, itemSize, candidate)) return candidate;
      }
    }

    return _clampItemPosition(Vector2(900, 690), itemSize);
  }

  Future<void> _runInteriorAction(Future<void> Function() action) async {
    if (_actionRunning) return;
    _actionRunning = true;
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('Error ejecutando acción interior: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _actionRunning = false;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_actionRunning) return;

    final worldTap = _screenToWorld(event.canvasPosition);

    if (isInteriorEditMode) {
      _selectInteriorItem(worldTap);
      return;
    }
    if (_isInside(worldTap, gamesZone)) {
      onOpenGames();
      return;
    }

    final tappedItem = _findFurnitureAt(worldTap);

    if (tappedItem != null) {
      switch (tappedItem.itemType) {
        case 'bed':
          _runInteriorAction(() => _sleepTogether(tappedItem.position));
          return;
        case 'sofa':
          _runInteriorAction(() => _sitOnSofa(tappedItem.position));
          return;
        case 'table':
          _runInteriorAction(() => _eatTogether(tappedItem.position));
          return;
        case 'tv':
          onOpenCinema();
          return;
        case 'plant':
          _runInteriorAction(() => _waterPlant(tappedItem.position));
          return;
        case 'pet_bed':
          _runInteriorAction(_petDog);
          return;
      }
    }

    if (_actorTappedBottom(dog, worldTap, width: 130, height: 125)) {
      _runInteriorAction(_petDog);
      return;
    }

    if (_actorTappedBottom(boy, worldTap, width: 150, height: 270) ||
        _actorTappedBottom(girl, worldTap, width: 150, height: 270)) {
      _runInteriorAction(_hugPartner);
      return;
    }

    final target = _findSafeWalkPoint(worldTap);

    boy.movePath(
      _buildSimpleRoute(boy.position, Vector2(target.x - 100, target.y)),
    );

    girl.movePath(
      _buildSimpleRoute(girl.position, Vector2(target.x + 100, target.y)),
    );

    dog.movePath(
      _buildSimpleRoute(dog.position, Vector2(target.x, target.y + 65)),
    );

    _addTapMarker(target);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isInteriorEditMode) return;

    final worldTap = _screenToWorld(event.canvasPosition);
    _selectInteriorItem(worldTap);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isInteriorEditMode) return;
    if (selectedInteriorItem == null) return;

    final zoom = camera.viewfinder.zoom;
    final delta = event.canvasDelta / zoom;

    final item = selectedInteriorItem!;
    final candidate = _clampItemPosition(item.position + delta, item.size);
    if (!_canPlaceItem(
      item.itemType,
      item.size,
      candidate,
      ignoredItem: item,
    )) {
      return;
    }

    item.position = candidate;

    item.priority = item.itemType == 'rug' ? 505 : candidate.y.toInt();
  }

  EditableInteriorItem? _findFurnitureAt(Vector2 point) {
    final sortedItems = [...furnitureItems]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final item in sortedItems) {
      if (item.containsWorldPoint(point)) {
        return item;
      }
    }

    return null;
  }

  Future<void> _sleepTogether(Vector2 bed) async {
    final boyTarget = Vector2(bed.x - 75, bed.y + 125);
    final girlTarget = Vector2(bed.x + 75, bed.y + 125);
    final dogTarget = Vector2(bed.x, bed.y + 185);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));
    dog.movePath(_buildSimpleRoute(dog.position, dogTarget));

    await _waitUntilActorsArrive([boy, girl, dog]);

    boy.position = boyTarget;
    girl.position = girlTarget;
    dog.position = dogTarget;

    boy.sleep();
    girl.sleep();
    dog.sleep();

    await onInteriorReward({
      'love': 6,
      'energy': 18,
      'coins': 0,
      'lastAction': 'Descansaron juntos 😴',
    });

    _addFloatingText(
      text: 'Descanso +18 ⚡',
      position: Vector2(bed.x, bed.y - 150),
    );
  }

  Future<void> _sitOnSofa(Vector2 sofa) async {
    final boyTarget = Vector2(sofa.x - 85, sofa.y + 130);
    final girlTarget = Vector2(sofa.x + 85, sofa.y + 130);
    final dogTarget = Vector2(sofa.x, sofa.y + 190);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));
    dog.movePath(_buildSimpleRoute(dog.position, dogTarget));

    await _waitUntilActorsArrive([boy, girl, dog]);

    boy.position = boyTarget;
    girl.position = girlTarget;
    dog.position = dogTarget;

    boy.sit();
    girl.sit();
    dog.sit();

    await onInteriorReward({
      'love': 5,
      'energy': 5,
      'coins': 4,
      'lastAction': 'Se sentaron juntos en el sofá 🛋️',
    });

    _addFloatingText(
      text: 'Relax juntos ❤️',
      position: Vector2(sofa.x, sofa.y - 145),
    );
  }

  Future<void> _eatTogether(Vector2 table) async {
    final boyTarget = Vector2(table.x - 115, table.y + 105);
    final girlTarget = Vector2(table.x + 115, table.y + 105);
    final dogTarget = Vector2(table.x, table.y + 165);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));
    dog.movePath(_buildSimpleRoute(dog.position, dogTarget));

    await _waitUntilActorsArrive([boy, girl, dog]);

    boy.position = boyTarget;
    girl.position = girlTarget;
    dog.position = dogTarget;

    boy.wave();
    girl.wave();
    dog.sit();

    await onInteriorReward({
      'love': 4,
      'energy': 10,
      'coins': 6,
      'lastAction': 'Comieron juntos 🍽️',
    });

    _addFloatingText(
      text: '+6 monedas 🪙',
      position: Vector2(table.x, table.y - 125),
    );
  }

  Future<void> _waterPlant(Vector2 plant) async {
    final boyTarget = Vector2(plant.x - 105, plant.y + 115);
    final girlTarget = Vector2(plant.x + 105, plant.y + 115);
    final dogTarget = Vector2(plant.x, plant.y + 170);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));
    dog.movePath(_buildSimpleRoute(dog.position, dogTarget));

    await _waitUntilActorsArrive([boy, girl, dog]);

    boy.position = boyTarget;
    girl.position = girlTarget;
    dog.position = dogTarget;

    boy.water();
    girl.water();
    dog.sit();

    await onInteriorReward({
      'love': 2,
      'energy': 1,
      'coins': 4,
      'lastAction': 'Cuidaron una planta interior 🪴',
    });

    _addFloatingText(
      text: 'Planta feliz 🪴',
      position: Vector2(plant.x, plant.y - 145),
    );
  }

  Future<void> _petDog() async {
    final dogTarget = dog.position.clone();
    final boyTarget = Vector2(dogTarget.x - 115, dogTarget.y - 20);
    final girlTarget = Vector2(dogTarget.x + 115, dogTarget.y - 20);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));

    await _waitUntilActorsArrive([boy, girl]);

    boy.position = boyTarget;
    girl.position = girlTarget;

    boy.wave();
    girl.wave();
    dog.wave();

    await onInteriorReward({
      'love': 3,
      'energy': 0,
      'coins': 2,
      'lastAction': 'Acariciaron a Pawdo dentro de casa 🐶',
    });

    _addFloatingText(
      text: 'Pawdo feliz 🐶',
      position: Vector2(dogTarget.x, dogTarget.y - 145),
    );
  }

  Future<void> _hugPartner() async {
    final boyTarget = Vector2(820, 710);
    final girlTarget = Vector2(980, 710);
    final dogTarget = Vector2(900, 770);

    boy.movePath(_buildSimpleRoute(boy.position, boyTarget));
    girl.movePath(_buildSimpleRoute(girl.position, girlTarget));
    dog.movePath(_buildSimpleRoute(dog.position, dogTarget));

    await _waitUntilActorsArrive([boy, girl, dog]);

    boy.position = boyTarget;
    girl.position = girlTarget;
    dog.position = dogTarget;

    boy.hug();
    girl.hug();
    dog.sit();

    await onInteriorReward({
      'love': 8,
      'energy': 0,
      'coins': 0,
      'lastAction': 'Abrazo dentro de casa ❤️',
    });

    _addFloatingText(text: 'Abrazo ❤️', position: Vector2(900, 555));
  }

  Future<void> _waitUntilActorsArrive(
    List<AnimatedActorComponent> actors,
  ) async {
    int loops = 0;

    while (actors.any((actor) => actor.isMoving) && loops < 90) {
      await Future.delayed(const Duration(milliseconds: 100));
      loops++;
    }
  }

  List<Vector2> _buildSimpleRoute(Vector2 from, Vector2 to) {
    final safeTo = _findSafeWalkPoint(to);

    const laneY = 760.0;

    final p1 = _findSafeWalkPoint(Vector2(from.x, laneY));
    final p2 = _findSafeWalkPoint(Vector2(safeTo.x, laneY));
    final p3 = safeTo;

    final route = <Vector2>[];

    if ((p1 - from).length > 8) route.add(p1);
    if ((p2 - p1).length > 8) route.add(p2);
    if ((p3 - p2).length > 8) route.add(p3);

    return route.isEmpty ? [safeTo] : route;
  }

  Vector2 _findSafeWalkPoint(Vector2 point) {
    double x = point.x;
    double y = point.y;

    if (x < walkableArea.left) x = walkableArea.left;
    if (x > walkableArea.right) x = walkableArea.right;

    if (y < walkableArea.top) y = walkableArea.top;
    if (y > walkableArea.bottom) y = walkableArea.bottom;

    return Vector2(x, y);
  }

  Vector2 _screenToWorld(Vector2 screenPosition) {
    final screenCenter = size / 2;
    final worldCenter = camera.viewfinder.position;
    final zoom = camera.viewfinder.zoom;

    return worldCenter + ((screenPosition - screenCenter) / zoom);
  }

  bool _actorTappedBottom(
    PositionComponent actor,
    Vector2 point, {
    required double width,
    required double height,
  }) {
    final left = actor.position.x - width / 2;
    final right = actor.position.x + width / 2;
    final top = actor.position.y - height;
    final bottom = actor.position.y;

    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  bool _isInside(Vector2 point, Rect rect) {
    return point.x >= rect.left &&
        point.x <= rect.right &&
        point.y >= rect.top &&
        point.y <= rect.bottom;
  }

  void _addTapMarker(Vector2 position) {
    final marker = CircleComponent(
      position: position,
      radius: 18,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..style = PaintingStyle.fill,
      priority: sceneDepthPriority(
        layer: SceneDepthLayer.overlay,
        baselineY: position.y,
      ),
    );

    world.add(marker);

    Future.delayed(const Duration(milliseconds: 450), () {
      marker.removeFromParent();
    });
  }

  void _addFloatingText({required String text, required Vector2 position}) {
    final textComponent = TextComponent(
      text: text,
      position: position,
      anchor: Anchor.center,
      priority: sceneDepthPriority(
        layer: SceneDepthLayer.overlay,
        baselineY: position.y,
        tieBreaker: 1,
      ),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.pink,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    world.add(textComponent);

    Future.delayed(const Duration(milliseconds: 1300), () {
      textComponent.removeFromParent();
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_actionRunning || isInteriorEditMode) return;

    _dogTimer -= dt;

    if (_dogTimer <= 0) {
      _dogTimer = 5.0;

      final target = _findSafeWalkPoint(
        Vector2(
          900 + (_random.nextDouble() * 360 - 180),
          735 + (_random.nextDouble() * 70 - 35),
        ),
      );

      dog.movePath(_buildSimpleRoute(dog.position, target));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final zoomX = size.x / roomWidth;
    final zoomY = size.y / roomHeight;

    camera.viewfinder.zoom = math.max(zoomX, zoomY) * 1.05;
    camera.viewfinder.position = Vector2(roomWidth / 2, 470);
  }
}
