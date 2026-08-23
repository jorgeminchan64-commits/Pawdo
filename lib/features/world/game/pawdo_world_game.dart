import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../characters/models/character_appearance.dart';

import '../components/actors/animated_actor_component.dart';
import '../components/depth_priority.dart';
import '../components/editable_garden_item.dart';
import '../components/scene_atmosphere_component.dart';
import '../models/garden_interaction_policy.dart';

class PawdoWorldGame extends FlameGame with TapCallbacks, DragCallbacks {
  PawdoWorldGame({
    required this.onOpenInterior,
    required this.onWorldReward,
    required this.onLayoutChanged,
  });

  final VoidCallback onOpenInterior;
  final Future<void> Function(Map<String, dynamic> reward) onWorldReward;
  final VoidCallback onLayoutChanged;

  static const double worldWidth = 1800;
  static const double worldHeight = 900;

  final math.Random _random = math.Random();

  late AnimatedActorComponent boy;
  late AnimatedActorComponent girl;
  late AnimatedActorComponent dog;

  SpriteComponent? tableSprite;
  SpriteComponent? houseSprite;
  String selectedHouseAssetPath = 'houses/house_basic.png';

  bool get isHouseReady => houseSprite != null;

  final List<EditableGardenItem> editableItems = [];
  EditableGardenItem? selectedEditableItem;

  bool get selectedItemCanBeDeleted => selectedEditableItem?.deletable == true;

  Set<String> get placedCatalogItemIds => editableItems
      .where((item) => !item.isSystemItem)
      .map((item) => item.catalogItemId)
      .toSet();

  bool isGardenEditMode = false;
  bool _actionRunning = false;

  double _dogTimer = 4.5;

  final Vector2 tablePos = Vector2(900, 625);
  final Vector2 plantPos = Vector2(590, 670);

  final Vector2 boyDogPoint = Vector2(790, 715);
  final Vector2 girlDogPoint = Vector2(1010, 715);
  final Vector2 dogHappyPoint = Vector2(900, 735);

  final Rect walkableArea = const Rect.fromLTWH(410, 505, 980, 260);

  final Rect houseZone = const Rect.fromLTWH(705, 180, 390, 280);
  final Rect houseBlockZone = const Rect.fromLTWH(690, 210, 430, 260);

  static const Map<String, String> _starterAssets = {
    'tree_big_love_01': 'garden/tree_big_love.png',
    'apple_tree_01': 'garden/apple_tree.png',
    'tree_flower_small_01': 'garden/tree_flower_small.png',
    'bush_flowers_01': 'garden/bush_flowers.png',
    'flower_bed_large_01': 'garden/flower_bed_large.png',
    'flower_box_long_01': 'garden/flower_box_long.png',
    'flower_pot_pink_01': 'garden/flower_pot_pink.png',
    'plant_water_01': 'garden/plant_level_2.png',
    'table_garden_01': 'garden/table_garden.png',
    'plant_special_love_01': 'garden/plant_special_love.png',
  };

  static const Map<String, String> _gardenTypesByAsset = {
    'garden/tree_big_love.png': 'tree',
    'garden/apple_tree.png': 'tree',
    'garden/tree_flower_small.png': 'tree',
    'garden/bush_flowers.png': 'bush',
    'garden/flower_bed_large.png': 'flowers',
    'garden/flower_box_long.png': 'flowers',
    'garden/flower_pot_pink.png': 'pot',
    'garden/plant_level_2.png': 'plant',
    'garden/table_garden.png': 'table',
    'garden/plant_special_love.png': 'special_plant',
  };

  static const Map<String, (double, double)> _gardenSizesByAsset = {
    'garden/tree_big_love.png': (330, 330),
    'garden/apple_tree.png': (275, 275),
    'garden/tree_flower_small.png': (155, 155),
    'garden/bush_flowers.png': (205, 115),
    'garden/flower_bed_large.png': (320, 125),
    'garden/flower_box_long.png': (355, 118),
    'garden/flower_pot_pink.png': (105, 105),
    'garden/plant_level_2.png': (155, 110),
    'garden/table_garden.png': (205, 130),
    'garden/plant_special_love.png': (118, 92),
  };

  static const Set<String> _essentialStarterIds = {
    'plant_water_01',
    'table_garden_01',
  };

  String _catalogItemIdFromAsset(String assetPath, {required String itemId}) {
    if (_starterAssets.containsKey(itemId)) return 'system_$itemId';
    final fileName = assetPath.split('/').last;
    return fileName.endsWith('.png')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
  }

  Rect _placementFootprint(EditableGardenItem item, Vector2 position) {
    final width = math.max(48.0, item.size.x * 0.58);
    final height = math.max(36.0, item.size.y * 0.28);
    return Rect.fromCenter(
      center: Offset(position.x, position.y + item.size.y * 0.30),
      width: width,
      height: height,
    );
  }

  Vector2 _clampGardenPosition(EditableGardenItem item, Vector2 candidate) {
    final halfWidth = math.max(36.0, item.size.x / 2);
    final halfHeight = math.max(36.0, item.size.y / 2);
    final minX = math.max(120.0, halfWidth);
    final maxX = math.min(1680.0, worldWidth - halfWidth);
    final minY = math.max(120.0, halfHeight);
    final maxY = math.min(820.0, worldHeight - halfHeight);
    return Vector2(
      candidate.x.clamp(minX, maxX).toDouble(),
      candidate.y.clamp(minY, maxY).toDouble(),
    );
  }

  bool _canPlaceItem(EditableGardenItem item, Vector2 candidate) {
    final footprint = _placementFootprint(item, candidate);
    if (footprint.overlaps(houseBlockZone.inflate(10))) return false;

    for (final other in editableItems) {
      if (identical(other, item)) continue;
      if (footprint.overlaps(_placementFootprint(other, other.position))) {
        return false;
      }
    }
    return true;
  }

  Rect _rectFromCenter(Vector2 center, double width, double height) {
    return Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: width,
      height: height,
    );
  }

  EditableGardenItem? _findEditableItemById(String id) {
    for (final item in editableItems) {
      if (item.itemId == id) {
        return item;
      }
    }

    return null;
  }

  EditableGardenItem? _findEditableItemAt(Vector2 worldPoint) {
    final sortedItems = [...editableItems]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final item in sortedItems) {
      if (item.containsWorldPoint(worldPoint)) {
        return item;
      }
    }

    return null;
  }

  List<Rect> get blockedZones {
    final zones = <Rect>[houseBlockZone];

    for (final item in editableItems) {
      if (item.itemType == 'tree') {
        zones.add(
          _rectFromCenter(
            item.position,
            item.size.x * 0.65,
            item.size.y * 0.60,
          ),
        );
      } else if (item.itemType == 'table') {
        zones.add(
          _rectFromCenter(
            item.position,
            item.size.x * 0.90,
            item.size.y * 0.75,
          ),
        );
      } else if (item.itemType == 'plant' ||
          item.itemType == 'special_plant' ||
          item.itemType == 'pot') {
        zones.add(
          _rectFromCenter(
            item.position,
            item.size.x * 0.85,
            item.size.y * 0.75,
          ),
        );
      } else if (item.itemType == 'flowers' || item.itemType == 'bush') {
        zones.add(
          _rectFromCenter(
            item.position,
            item.size.x * 0.90,
            item.size.y * 0.70,
          ),
        );
      }
    }

    return zones;
  }

  @override
  Color backgroundColor() => const Color(0xFFFFEEF5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(worldWidth / 2, 470);

    await _loadWorld();
  }

  Future<void> _loadWorld() async {
    await _addHouseSprite(selectedHouseAssetPath);

    await _addGardenDecoration();

    final garden = await images.load('backgrounds/garden_basic.png');

    world.add(
      SpriteComponent(
        sprite: Sprite(garden),
        position: Vector2(-100, -60),
        size: Vector2(worldWidth + 200, worldHeight + 120),
        anchor: Anchor.topLeft,
        priority: sceneDepthPriority(
          layer: SceneDepthLayer.background,
          baselineY: 0,
        ),
      ),
    );

    await _addInteractiveGardenObjects();

    boy = await _createHuman(
      const CharacterAppearance(),
      position: Vector2(790, 660),
      depthTieBreaker: 1,
    );
    girl = await _createHuman(
      const CharacterAppearance(baseStyle: CharacterBaseStyle.classicGirl),
      position: Vector2(1010, 660),
      depthTieBreaker: 2,
    );

    final dogSheet = await images.load('pets/dog_pro_spritesheet.png');

    dog = AnimatedActorComponent(
      spriteSheet: dogSheet,
      startPosition: Vector2(900, 725),
      size: Vector2(120, 120),
      spriteLayout: ActorSpriteLayout.dog,
      depthTieBreaker: 3,
      speed: 205,
      anchor: Anchor.bottomCenter,
    );

    world.add(dog);
    world.add(
      SceneAtmosphereComponent(
        sceneSize: Vector2(worldWidth, worldHeight),
        isIndoor: false,
      ),
    );
  }

  Future<AnimatedActorComponent> _createHuman(
    CharacterAppearance appearance, {
    required Vector2 position,
    required int depthTieBreaker,
  }) async {
    final isGirl = appearance.baseStyle == CharacterBaseStyle.classicGirl;
    final prefix = isGirl ? 'avatar_girl' : 'avatar_boy';
    final loaded = await Future.wait([
      images.load('avatars/${prefix}_pro_spritesheet.png'),
      images.load('avatars/layers/${prefix}_hair.png'),
      images.load('avatars/layers/${prefix}_skin.png'),
      images.load('avatars/layers/${prefix}_outfit.png'),
      images.load('avatars/layers/${prefix}_shoes.png'),
    ]);
    final actor = AnimatedActorComponent(
      spriteSheet: loaded[0],
      startPosition: position,
      size: Vector2(150, 265),
      spriteLayout: isGirl ? ActorSpriteLayout.girl : ActorSpriteLayout.boy,
      appearanceLayers: ActorAppearanceLayers(
        appearance: appearance,
        hairMask: loaded[1],
        skinMask: loaded[2],
        outfitMask: loaded[3],
        shoesMask: loaded[4],
      ),
      depthTieBreaker: depthTieBreaker,
      speed: 155,
      anchor: Anchor.bottomCenter,
    );
    world.add(actor);
    _applyInitialPose(actor, appearance.pose);
    return actor;
  }

  Future<void> applyCharacterAppearances(
    CharacterAppearance first,
    CharacterAppearance second,
  ) async {
    final firstPosition = boy.position.clone();
    final secondPosition = girl.position.clone();
    boy.removeFromParent();
    girl.removeFromParent();
    boy = await _createHuman(
      first,
      position: firstPosition,
      depthTieBreaker: 1,
    );
    girl = await _createHuman(
      second,
      position: secondPosition,
      depthTieBreaker: 2,
    );
  }

  void _applyInitialPose(AnimatedActorComponent actor, CharacterPose pose) {
    switch (pose) {
      case CharacterPose.idle:
        return;
      case CharacterPose.wave:
        actor.wave();
      case CharacterPose.sit:
        actor.sit();
    }
  }

  Future<void> _addGardenDecoration() async {
    await _addEditableSprite(
      id: 'tree_big_love_01',
      type: 'tree',
      path: 'garden/tree_big_love.png',
      position: Vector2(455, 340),
      size: Vector2(330, 330),
      priority: 335,
    );

    await _addEditableSprite(
      id: 'apple_tree_01',
      type: 'tree',
      path: 'garden/apple_tree.png',
      position: Vector2(1285, 420),
      size: Vector2(275, 275),
      priority: 430,
    );

    await _addEditableSprite(
      id: 'tree_flower_small_01',
      type: 'tree',
      path: 'garden/tree_flower_small.png',
      position: Vector2(315, 575),
      size: Vector2(155, 155),
      priority: 565,
    );

    await _addEditableSprite(
      id: 'bush_flowers_01',
      type: 'bush',
      path: 'garden/bush_flowers.png',
      position: Vector2(1370, 660),
      size: Vector2(205, 115),
      priority: 690,
    );

    await _addEditableSprite(
      id: 'flower_bed_large_01',
      type: 'flowers',
      path: 'garden/flower_bed_large.png',
      position: Vector2(405, 780),
      size: Vector2(320, 125),
      priority: 805,
    );

    await _addEditableSprite(
      id: 'flower_box_long_01',
      type: 'flowers',
      path: 'garden/flower_box_long.png',
      position: Vector2(1280, 780),
      size: Vector2(355, 118),
      priority: 805,
    );

    await _addEditableSprite(
      id: 'flower_pot_pink_01',
      type: 'pot',
      path: 'garden/flower_pot_pink.png',
      position: Vector2(1115, 505),
      size: Vector2(105, 105),
      priority: 505,
    );
  }

  Future<void> _addInteractiveGardenObjects() async {
    await _addEditableSprite(
      id: 'plant_water_01',
      catalogItemId: 'system_plant_water',
      type: 'plant',
      path: 'garden/plant_level_2.png',
      position: plantPos,
      size: Vector2(155, 110),
      priority: 670,
      isSystemItem: true,
      deletable: false,
    );

    final table = await _addEditableSprite(
      id: 'table_garden_01',
      catalogItemId: 'system_table_garden',
      type: 'table',
      path: 'garden/table_garden.png',
      position: tablePos,
      size: Vector2(205, 130),
      priority: 625,
      isSystemItem: true,
      deletable: false,
    );

    tableSprite = table;

    await _addEditableSprite(
      id: 'plant_special_love_01',
      type: 'special_plant',
      path: 'garden/plant_special_love.png',
      position: Vector2(1160, 625),
      size: Vector2(118, 92),
      priority: 625,
    );
  }

  Future<void> _addHouseSprite(String assetPath) async {
    selectedHouseAssetPath = assetPath;

    final houseImage = await images.load(assetPath);

    houseSprite = _GroundedHouseComponent(
      sprite: Sprite(houseImage),
      position: Vector2(worldWidth / 2, 350),
      size: Vector2(440, 440),
    );

    world.add(houseSprite!);
  }

  Future<void> changeHouseModel(String assetPath) async {
    selectedHouseAssetPath = assetPath;

    final image = await images.load(assetPath);

    if (houseSprite == null) {
      await _addHouseSprite(assetPath);
      return;
    }

    houseSprite!.sprite = Sprite(image);
  }

  Future<void> changeGardenPlantStage(int stage) async {
    final plant = _findEditableItemById('plant_water_01');
    if (plant == null) return;
    final safeStage = stage.clamp(1, 3);
    final image = await images.load('garden/plant_level_$safeStage.png');
    plant.sprite = Sprite(image);
  }

  Future<EditableGardenItem> _addEditableSprite({
    required String id,
    String? catalogItemId,
    required String type,
    required String path,
    required Vector2 position,
    required Vector2 size,
    required int priority,
    bool isSystemItem = false,
    bool deletable = true,
  }) async {
    final image = await images.load(path);

    final item = EditableGardenItem(
      itemId: id,
      catalogItemId: catalogItemId ?? _catalogItemIdFromAsset(path, itemId: id),
      itemType: type,
      assetPath: path,
      isSystemItem: isSystemItem || _starterAssets.containsKey(id),
      deletable: !_essentialStarterIds.contains(id) && deletable,
      sprite: Sprite(image),
      position: position,
      size: size,
      priority: priority,
    );

    editableItems.add(item);
    world.add(item);

    return item;
  }

  void setGardenEditMode(bool value) {
    isGardenEditMode = value;

    if (!value) {
      _clearSelectedEditableItem();
    }
  }

  List<Map<String, dynamic>> exportGardenLayout() {
    return editableItems.map((item) => item.toJson()).toList();
  }

  Future<void> loadGardenLayout(List<dynamic> layout) async {
    if (editableItems.isEmpty) return;
    _clearSelectedEditableItem();

    final savedIds = <String>{};
    final placedCatalogIds = <String>{};

    for (final rawItem in layout) {
      if (rawItem is! Map) continue;

      final id = rawItem['id']?.toString();
      final type = rawItem['type']?.toString();
      final asset = rawItem['asset']?.toString();

      if (id == null || type == null || asset == null) continue;

      final expectedType = _gardenTypesByAsset[asset];
      final canonicalSize = _gardenSizesByAsset[asset];
      if (expectedType == null ||
          expectedType != type ||
          canonicalSize == null) {
        continue;
      }
      final starterAsset = _starterAssets[id];
      if (starterAsset != null && starterAsset != asset) continue;
      if (starterAsset == null && asset == 'garden/plant_level_2.png') continue;

      final inferredCatalogItemId = _catalogItemIdFromAsset(asset, itemId: id);
      final rawCatalogItemId = rawItem['catalogItemId']?.toString();
      if (starterAsset == null &&
          rawCatalogItemId != null &&
          rawCatalogItemId != inferredCatalogItemId) {
        continue;
      }
      final catalogItemId = inferredCatalogItemId;
      final isSystemItem = starterAsset != null;
      final deletable = !_essentialStarterIds.contains(id);

      if (!isSystemItem && !placedCatalogIds.add(catalogItemId)) continue;
      savedIds.add(id);

      EditableGardenItem? existingItem = _findEditableItemById(id);

      final x = rawItem['x'];
      final y = rawItem['y'];
      final priority = rawItem['priority'];

      final safeX = x is num && x.isFinite
          ? x.toDouble().clamp(120, 1680).toDouble()
          : 900.0;
      final safeY = y is num && y.isFinite
          ? y.toDouble().clamp(120, 820).toDouble()
          : 650.0;
      final position = Vector2(safeX, safeY);
      final size = Vector2(canonicalSize.$1, canonicalSize.$2);

      final itemPriority = priority is num
          ? priority.toInt()
          : position.y.toInt();

      if (existingItem != null) {
        existingItem.position = position;
        existingItem.size = size;
        existingItem.priority = itemPriority;

        if (existingItem.itemType == 'table') {
          tableSprite = existingItem;
        }
      } else {
        final newItem = await _addEditableSprite(
          id: id,
          catalogItemId: catalogItemId,
          type: type,
          path: asset,
          position: position,
          size: size,
          priority: itemPriority,
          isSystemItem: isSystemItem,
          deletable: deletable,
        );

        if (newItem.itemType == 'table') {
          tableSprite = newItem;
        }
      }
    }

    for (final item in List<EditableGardenItem>.from(editableItems)) {
      if (!savedIds.contains(item.itemId)) {
        if (!item.deletable) continue;
        if (tableSprite == item) {
          tableSprite = null;
        }

        item.removeFromParent();
        editableItems.remove(item);
      }
    }
  }

  Future<bool> addGardenItem({
    required String catalogItemId,
    required String type,
    required String assetPath,
    required Vector2 size,
  }) async {
    if (editableItems.any(
      (item) => !item.isSystemItem && item.catalogItemId == catalogItemId,
    )) {
      return false;
    }

    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';

    final item = await _addEditableSprite(
      id: id,
      catalogItemId: catalogItemId,
      type: type,
      path: assetPath,
      position: Vector2(900, 650),
      size: size,
      priority: 650,
    );

    Vector2? newPosition;
    for (var attempt = 0; attempt < 30; attempt++) {
      final candidate = _clampGardenPosition(
        item,
        Vector2(
          650 + _random.nextDouble() * 500,
          540 + _random.nextDouble() * 250,
        ),
      );
      if (_canPlaceItem(item, candidate)) {
        newPosition = candidate;
        break;
      }
    }

    if (newPosition == null) {
      item.removeFromParent();
      editableItems.remove(item);
      return false;
    }

    item.position = newPosition;
    item.priority = newPosition.y.toInt();

    if (type == 'table') {
      tableSprite = item;
    }

    _clearSelectedEditableItem();
    selectedEditableItem = item;
    item.isSelected = true;
    onLayoutChanged();
    return true;
  }

  bool deleteSelectedGardenItem() {
    final item = selectedEditableItem;

    if (item == null) return false;
    if (!item.deletable) return false;

    if (tableSprite == item) {
      tableSprite = null;
    }

    item.removeFromParent();
    editableItems.remove(item);
    selectedEditableItem = null;
    onLayoutChanged();

    return true;
  }

  void _clearSelectedEditableItem() {
    for (final item in editableItems) {
      item.isSelected = false;
    }

    selectedEditableItem = null;
  }

  bool _selectEditableItem(Vector2 worldTap) {
    _clearSelectedEditableItem();

    final item = _findEditableItemAt(worldTap);

    if (item == null) return false;

    selectedEditableItem = item;
    item.isSelected = true;

    return true;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_actionRunning) return;

    final worldTap = _screenToWorld(event.canvasPosition);

    if (isGardenEditMode) {
      _selectEditableItem(worldTap);
      return;
    }

    if (_isInside(worldTap, houseZone)) {
      onOpenInterior();
      return;
    }

    final tappedItem = _findEditableItemAt(worldTap);

    if (tappedItem != null) {
      switch (GardenInteractionPolicy.actionForType(tappedItem.itemType)) {
        case GardenItemAction.water:
          _waterPlant(tappedItem);
          return;
        case GardenItemAction.sit:
          _sitTogether(tappedItem);
          return;
        case GardenItemAction.none:
          break;
      }
    }

    if (_actorTappedBottom(dog, worldTap, width: 130, height: 125)) {
      _petDog();
      return;
    }

    if (_actorTappedBottom(boy, worldTap, width: 150, height: 270) ||
        _actorTappedBottom(girl, worldTap, width: 150, height: 270)) {
      _hugPartner();
      return;
    }

    final target = _findSafeWalkPoint(worldTap);

    boy.movePath(
      _buildSmartRoute(boy.position, Vector2(target.x - 105, target.y)),
    );

    girl.movePath(
      _buildSmartRoute(girl.position, Vector2(target.x + 105, target.y + 8)),
    );

    dog.movePath(
      _buildSmartRoute(dog.position, Vector2(target.x, target.y + 70)),
    );

    _addTapMarker(target);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isGardenEditMode) return;

    final worldTap = _screenToWorld(event.canvasPosition);
    _selectEditableItem(worldTap);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isGardenEditMode) return;
    if (selectedEditableItem == null) return;

    final zoom = camera.viewfinder.zoom;
    final delta = event.canvasDelta / zoom;

    final item = selectedEditableItem!;
    final candidate = _clampGardenPosition(item, item.position + delta);
    if (!_canPlaceItem(item, candidate)) return;

    item.position = candidate;
    item.priority = item.position.y.toInt();
    onLayoutChanged();
  }

  Future<void> _waterPlant(EditableGardenItem plantItem) async {
    if (!GardenInteractionPolicy.isWaterable(plantItem.itemType)) return;
    _actionRunning = true;
    try {
      final plant = plantItem.position;
      final boyTarget = Vector2(plant.x - 105, plant.y + 40);
      final girlTarget = Vector2(plant.x + 105, plant.y + 40);
      final dogTarget = Vector2(plant.x, plant.y + 75);

      boy.movePath(_buildSmartRoute(boy.position, boyTarget));
      girl.movePath(_buildSmartRoute(girl.position, girlTarget));
      dog.movePath(_buildSmartRoute(dog.position, dogTarget));

      await _waitUntilActorsArrive([boy, girl, dog]);

      boy.position = boyTarget;
      girl.position = girlTarget;
      dog.position = dogTarget;

      boy.water();
      girl.water();

      await onWorldReward({
        'coins': 10,
        'plants': 1,
        'lastAction': 'Regaron plantas 🌱',
      });

      _addFloatingText(
        text: "Regaron plantas 🌱 +10",
        position: Vector2(plant.x, plant.y - 130),
      );
    } finally {
      _actionRunning = false;
    }
  }

  Future<void> _sitTogether(EditableGardenItem tableItem) async {
    _actionRunning = true;
    try {
      final table = tableItem.position;

      final boyTarget = Vector2(table.x - 100, table.y + 110);
      final girlTarget = Vector2(table.x + 100, table.y + 110);
      final dogTarget = Vector2(table.x, table.y + 180);

      boy.movePath(_buildSmartRoute(boy.position, boyTarget));
      girl.movePath(_buildSmartRoute(girl.position, girlTarget));
      dog.movePath(_buildSmartRoute(dog.position, dogTarget));

      await _waitUntilActorsArrive([boy, girl, dog]);

      boy.position = boyTarget;
      girl.position = girlTarget;
      dog.position = dogTarget;

      await _showCoupleSittingScene(table, tableItem);

      boy.position = Vector2(table.x - 100, table.y + 75);
      girl.position = Vector2(table.x + 100, table.y + 75);
      dog.position = Vector2(table.x, table.y + 110);

      await onWorldReward({
        'love': 5,
        'energy': 2,
        'lastAction': 'Se sentaron juntos ❤️',
      });

      _addFloatingText(
        text: "Momento juntos ❤️ +5",
        position: Vector2(table.x, table.y - 95),
      );
    } finally {
      _actionRunning = false;
    }
  }

  Future<void> _petDog() async {
    _actionRunning = true;
    try {
      boy.movePath(_buildSmartRoute(boy.position, boyDogPoint));
      girl.movePath(_buildSmartRoute(girl.position, girlDogPoint));
      dog.movePath(_buildSmartRoute(dog.position, dogHappyPoint));

      await _waitUntilActorsArrive([boy, girl, dog]);

      boy.position = boyDogPoint;
      girl.position = girlDogPoint;
      dog.position = dogHappyPoint;

      dog.wave();
      boy.wave();
      girl.wave();

      await onWorldReward({'love': 2, 'lastAction': 'Acariciaron a Pawdo 🐶'});

      _addFloatingText(text: "Pawdo feliz 🐶❤️", position: Vector2(900, 555));
    } finally {
      _actionRunning = false;
    }
  }

  Future<void> _hugPartner() async {
    _actionRunning = true;
    try {
      final boyTarget = Vector2(830, 675);
      final girlTarget = Vector2(970, 675);
      final dogTarget = Vector2(900, 740);

      boy.movePath(_buildSmartRoute(boy.position, boyTarget));
      girl.movePath(_buildSmartRoute(girl.position, girlTarget));
      dog.movePath(_buildSmartRoute(dog.position, dogTarget));

      await _waitUntilActorsArrive([boy, girl, dog]);

      boy.position = boyTarget;
      girl.position = girlTarget;
      dog.position = dogTarget;

      boy.hug();
      girl.hug();

      await onWorldReward({'love': 8, 'lastAction': 'Abrazo de pareja ❤️'});

      _addFloatingText(
        text: "Abrazo de pareja ❤️ +8",
        position: Vector2(900, 520),
      );
    } finally {
      _actionRunning = false;
    }
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

  List<Vector2> _buildSmartRoute(Vector2 from, Vector2 to) {
    final safeTo = _findSafeWalkPoint(to);

    const laneY = 748.0;

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
    final clamped = _clampToWalkableArea(point);

    if (_isSafePoint(clamped)) {
      return clamped;
    }

    final candidates = <Vector2>[
      Vector2(clamped.x, clamped.y + 65),
      Vector2(clamped.x, clamped.y - 65),
      Vector2(clamped.x - 85, clamped.y),
      Vector2(clamped.x + 85, clamped.y),
      Vector2(clamped.x - 95, clamped.y + 55),
      Vector2(clamped.x + 95, clamped.y + 55),
      Vector2(clamped.x - 95, clamped.y - 55),
      Vector2(clamped.x + 95, clamped.y - 55),
      Vector2(worldWidth / 2, 735),
    ];

    Vector2 bestPoint = Vector2(worldWidth / 2, 735);
    double bestDistance = double.infinity;

    for (final candidate in candidates) {
      final safe = _clampToWalkableArea(candidate);

      if (!_isSafePoint(safe)) continue;

      final distance = (safe - clamped).length;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestPoint = safe;
      }
    }

    return bestPoint;
  }

  bool _isSafePoint(Vector2 point) {
    if (!_isInside(point, walkableArea)) return false;

    for (final rect in blockedZones) {
      if (_isInside(point, rect)) return false;
    }

    return true;
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

  Vector2 _clampToWalkableArea(Vector2 point) {
    double x = point.x;
    double y = point.y;

    if (x < walkableArea.left) x = walkableArea.left;
    if (x > walkableArea.right) x = walkableArea.right;

    if (y < walkableArea.top) y = walkableArea.top;
    if (y > walkableArea.bottom) y = walkableArea.bottom;

    return Vector2(x, y);
  }

  void _addTapMarker(Vector2 position) {
    final marker = CircleComponent(
      position: position,
      radius: 18,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
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

    Future.delayed(const Duration(milliseconds: 1200), () {
      textComponent.removeFromParent();
    });
  }

  Future<void> _showCoupleSittingScene(
    Vector2 table,
    SpriteComponent tableComponent,
  ) async {
    final boyScale = boy.scale.clone();
    final girlScale = girl.scale.clone();
    final dogScale = dog.scale.clone();
    final tableScale = tableComponent.scale.clone();

    boy.scale = Vector2.zero();
    girl.scale = Vector2.zero();
    dog.scale = Vector2.zero();
    tableComponent.scale = Vector2.zero();

    final image = await images.load('actions/couple_sitting_table.png');

    final scene = SpriteComponent(
      sprite: Sprite(image),
      position: Vector2(table.x, table.y + 160),
      size: Vector2(470, 315),
      anchor: Anchor.bottomCenter,
      priority: sceneDepthPriority(
        layer: SceneDepthLayer.entity,
        baselineY: table.y + 160,
        tieBreaker: 8,
      ),
    );

    world.add(scene);

    await Future.delayed(const Duration(milliseconds: 3200));

    scene.removeFromParent();

    boy.scale = boyScale;
    girl.scale = girlScale;
    dog.scale = dogScale;
    tableComponent.scale = tableScale;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_actionRunning || isGardenEditMode) return;

    _dogTimer -= dt;

    if (_dogTimer <= 0) {
      _dogTimer = 5.0;

      final target = _findSafeWalkPoint(
        _randomWalkPoint(
          center: Vector2(worldWidth / 2, 720),
          rangeX: 230,
          rangeY: 35,
        ),
      );

      dog.movePath(_buildSmartRoute(dog.position, target));
    }
  }

  Vector2 _randomWalkPoint({
    required Vector2 center,
    required double rangeX,
    required double rangeY,
  }) {
    final x = center.x + (_random.nextDouble() * 2 - 1) * rangeX;
    final y = center.y + (_random.nextDouble() * 2 - 1) * rangeY;

    return Vector2(x, y);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final zoomX = size.x / worldWidth;
    final zoomY = size.y / worldHeight;

    camera.viewfinder.zoom = math.max(zoomX, zoomY) * 1.05;
    camera.viewfinder.position = Vector2(worldWidth / 2, 470);
  }
}

class _GroundedHouseComponent extends SpriteComponent {
  _GroundedHouseComponent({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: sceneDepthPriority(
           layer: SceneDepthLayer.entity,
           baselineY: position.y + size.y / 2,
         ),
       );

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .82),
        width: size.x * .66,
        height: size.y * .09,
      ),
      Paint()
        ..color = const Color(0xFF3C2E38).withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    super.render(canvas);
  }
}
