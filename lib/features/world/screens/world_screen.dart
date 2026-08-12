import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/landscape_game_body.dart';
import '../../characters/models/character_appearance.dart';
import '../../shop/data/garden_shop_items.dart';
import '../../shop/screens/garden_shop_screen.dart';
import '../../interior/screens/pawdo_interior_screen.dart';
import '../game/pawdo_world_game.dart';
import '../models/garden_interaction_policy.dart';
import '../services/layout_service.dart';
import '../../economy/services/economy_service.dart';

class WorldScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const WorldScreen({super.key, required this.onNavigate});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  late final PawdoWorldGame game;
  late final Future<String?> _coupleCodeFuture;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LayoutService _layoutService = LayoutService();

  bool isEditingGarden = false;
  bool _isSavingGarden = false;
  bool _isEquippingHouse = false;
  bool _hasUnsavedChanges = false;
  int _visiblePlantStage = 1;
  int _gardenRevision = 0;

  @override
  void initState() {
    super.initState();

    _coupleCodeFuture = _getCoupleCode();

    game = PawdoWorldGame(
      onOpenInterior: _openInterior,
      onWorldReward: _applyWorldReward,
      onLayoutChanged: _markLayoutDirty,
    );

    _setLandscape();
    _loadGardenLayoutFromFirebase();
    _loadSelectedHouseFromFirebase();
  }

  Future<String?> _getCoupleCode() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    return userDoc.data()?['coupleCode']?.toString();
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  Set<String> _ownedGardenItemsFromData(Map<String, dynamic> data) {
    final rawOwned = data['ownedGardenItems'];

    if (rawOwned is List) {
      return rawOwned.map((item) => item.toString()).toSet();
    }

    return {};
  }

  Future<void> _applyWorldReward(Map<String, dynamic> reward) async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final actionText = reward['lastAction']?.toString().toLowerCase() ?? '';
    final actionId = actionText.contains('planta')
        ? 'world_water'
        : actionText.contains('sentaron')
        ? 'world_sit'
        : actionText.contains('pawdo')
        ? 'world_pet'
        : actionText.contains('abrazo')
        ? 'world_hug'
        : null;
    if (actionId == null) return;
    final serverResult = await EconomyService().performAction(
      coupleCode: coupleCode,
      actionId: actionId,
    );
    final returnedStage = serverResult['plantStage'];
    if (actionId == 'world_water' && returnedStage is num) {
      await game.changeGardenPlantStage(returnedStage.toInt());
      _visiblePlantStage = returnedStage.toInt().clamp(1, 3);
    }
    if (mounted && serverResult['alreadyClaimed'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta recompensa diaria ya fue reclamada hoy ✅'),
        ),
      );
    }
  }

  Future<void> _loadGardenLayoutFromFirebase() async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final doc = await _db.collection('couples').doc(coupleCode).get();
    final data = doc.data() ?? {};
    final layout = data['gardenLayout'];
    final revision = _toInt(data['gardenRevision'], 0);
    final plantData = data['gardenPlant'];
    final plantStage = plantData is Map
        ? _toInt(plantData['stage'], 1).clamp(1, 3)
        : 1;

    await game.loaded;
    await _applySharedCharacterAppearances(data);

    for (int i = 0; i < 20; i++) {
      if (game.editableItems.isNotEmpty) {
        if (layout is List) await game.loadGardenLayout(layout);
        await game.changeGardenPlantStage(plantStage);
        if (mounted) {
          setState(() {
            _gardenRevision = revision;
            _visiblePlantStage = plantStage;
            _hasUnsavedChanges = false;
          });
        }
        return;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _applySharedCharacterAppearances(
    Map<String, dynamic> coupleData,
  ) async {
    final profiles = coupleData['memberProfiles'];
    final firstUid = coupleData['user1']?.toString();
    final secondUid = coupleData['user2']?.toString();
    final firstRaw = profiles is Map && firstUid != null
        ? profiles[firstUid]
        : null;
    final secondRaw = profiles is Map && secondUid != null
        ? profiles[secondUid]
        : null;
    final firstAppearance = firstRaw is Map
        ? CharacterAppearance.fromMap(firstRaw['characterAppearance'])
        : const CharacterAppearance();
    final secondAppearance = secondRaw is Map
        ? CharacterAppearance.fromMap(
            secondRaw['characterAppearance'],
            fallback: const CharacterAppearance(
              baseStyle: CharacterBaseStyle.classicGirl,
            ),
          )
        : const CharacterAppearance(baseStyle: CharacterBaseStyle.classicGirl);
    await game.applyCharacterAppearances(firstAppearance, secondAppearance);
  }

  Future<void> _loadSelectedHouseFromFirebase() async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final doc = await _db.collection('couples').doc(coupleCode).get();
    final data = doc.data() ?? {};

    final selectedHouseId = data['selectedHouseId']?.toString();
    final ownedItems = _ownedGardenItemsFromData(data);
    final requestedHouse = findGardenShopItemById(
      selectedHouseId ?? 'house_basic',
    );
    final houseItem =
        requestedHouse != null &&
            requestedHouse.isHouse &&
            !requestedHouse.isRealMoney &&
            !requestedHouse.comingSoonPremium &&
            (requestedHouse.isFree || ownedItems.contains(requestedHouse.id))
        ? requestedHouse
        : findGardenShopItemById('house_basic');

    if (houseItem == null) return;

    for (int i = 0; i < 20; i++) {
      if (game.isHouseReady) {
        await game.changeHouseModel(houseItem.assetPath);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _saveGardenLayout() async {
    if (_isSavingGarden) return;
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final layout = game.exportGardenLayout();

    setState(() => _isSavingGarden = true);
    try {
      _gardenRevision = await _layoutService.saveSharedLayout(
        coupleCode: coupleCode,
        area: 'garden',
        layout: layout,
        expectedRevision: _gardenRevision,
      );
      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jardín guardado ✅')));
    } on LayoutException catch (error) {
      if (!mounted) return;
      if (error.code == 'aborted') {
        final reload = await _showGardenConflictDialog();
        if (reload == true) await _reloadGardenLayout();
      } else {
        _showGardenError('No se pudo guardar el jardín. Intenta de nuevo.');
      }
    } catch (_) {
      if (mounted) {
        _showGardenError('No se pudo guardar el jardín. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isSavingGarden = false);
    }
  }

  Future<bool?> _showGardenConflictDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('El jardín cambió'),
        content: const Text(
          'Tu pareja guardó cambios desde otro teléfono. Recarga la versión más reciente antes de volver a editar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadGardenLayout() async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    try {
      final doc = await _db.collection('couples').doc(coupleCode).get();
      final data = doc.data() ?? {};
      final layout = data['gardenLayout'];
      final revision = _toInt(data['gardenRevision'], 0);
      await game.loadGardenLayout(layout is List ? layout : const []);
      if (mounted) {
        setState(() {
          _gardenRevision = revision;
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Jardín actualizado ✅')));
      }
    } catch (_) {
      if (mounted) _showGardenError('No se pudo recargar el jardín.');
    }
  }

  Future<void> _equipHouse(GardenShopItem item) async {
    if (_isEquippingHouse) return;
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    setState(() => _isEquippingHouse = true);
    try {
      await _layoutService.equipHouse(coupleCode: coupleCode, houseId: item.id);
      await game.changeHouseModel(item.assetPath);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${item.name} aplicada 🏡')));
    } catch (_) {
      if (mounted) {
        _showGardenError('No se pudo aplicar esa casa. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isEquippingHouse = false);
    }
  }

  void _showGardenError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addGardenItem({
    required String catalogItemId,
    required String type,
    required String assetPath,
    required Vector2 size,
  }) async {
    final added = await game.addGardenItem(
      catalogItemId: catalogItemId,
      type: type,
      assetPath: assetPath,
      size: size,
    );
    if (!added && mounted) {
      _showGardenError(
        'Ese objeto ya está colocado o no hay un espacio libre para agregarlo.',
      );
    }
  }

  void _deleteSelectedGardenItem() {
    final hadSelection = game.selectedEditableItem != null;
    final canDelete = game.selectedItemCanBeDeleted;
    final deleted = game.deleteSelectedGardenItem();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Objeto eliminado 🗑️'
              : hadSelection && !canDelete
              ? 'Ese objeto es esencial y no se puede eliminar'
              : 'Primero selecciona un objeto',
        ),
      ),
    );
  }

  void _toggleGardenEditMode() {
    setState(() {
      isEditingGarden = !isEditingGarden;
    });

    game.setGardenEditMode(isEditingGarden);
  }

  void _markLayoutDirty() {
    if (!mounted || _hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _goToTab(int index) async {
    if (!await _confirmDiscardChanges()) return;
    if (isEditingGarden) {
      setState(() {
        isEditingGarden = false;
      });

      game.setGardenEditMode(false);
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (!mounted) return;

    widget.onNavigate(index);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'Los cambios de este jardín todavía no se guardaron para tu pareja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar cambios'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return false;
    setState(() => _hasUnsavedChanges = false);
    return true;
  }

  Future<void> _requestPop() async {
    if (!await _confirmDiscardChanges() || !mounted) return;
    Navigator.pop(context);
  }

  Future<void> _openInterior() async {
    if (isEditingGarden) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PawdoInteriorScreen()),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        body: LandscapeGameBody(
          onExit: _requestPop,
          landscapeChild: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: game)),

              Positioned(
                top: 18,
                left: 18,
                child: SafeArea(
                  child: _glassButton(
                    text: isEditingGarden
                        ? "Editando jardín ✏️"
                        : "Jardín Pawdo 🌿",
                    onTap: () {},
                  ),
                ),
              ),

              Positioned(
                top: 18,
                left: 190,
                right: 130,
                child: SafeArea(child: _buildHud()),
              ),

              Positioned(
                left: 18,
                bottom: 18,
                child: SafeArea(
                  child: Row(
                    children: [
                      _editGardenButton(
                        text: isEditingGarden
                            ? 'Salir edición'
                            : 'Editar jardín',
                        icon: isEditingGarden ? Icons.close : Icons.edit,
                        onTap: _toggleGardenEditMode,
                      ),
                      if (isEditingGarden) ...[
                        const SizedBox(width: 10),
                        _editGardenButton(
                          text: 'Agregar',
                          icon: Icons.add_circle,
                          onTap: _showGardenInventorySheet,
                        ),
                        const SizedBox(width: 10),
                        _editGardenButton(
                          text: 'Casa',
                          icon: Icons.home,
                          onTap: _showHouseSelectorSheet,
                        ),
                        const SizedBox(width: 10),
                        _editGardenButton(
                          text: _isSavingGarden
                              ? 'Guardando…'
                              : _hasUnsavedChanges
                              ? 'Guardar *'
                              : 'Guardado',
                          icon: Icons.save,
                          onTap: _saveGardenLayout,
                        ),
                        const SizedBox(width: 10),
                        _editGardenButton(
                          text: 'Eliminar',
                          icon: Icons.delete,
                          onTap: _deleteSelectedGardenItem,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (!isEditingGarden)
                Positioned(
                  right: 18,
                  top: 18,
                  bottom: 18,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleMenuButton(
                          icon: Icons.pets,
                          label: "Mascota",
                          onTap: () => _goToTab(1),
                        ),
                        const SizedBox(height: 12),
                        _circleMenuButton(
                          icon: Icons.chat,
                          label: "Chat",
                          onTap: () => _goToTab(2),
                        ),
                        const SizedBox(height: 12),
                        _circleMenuButton(
                          icon: Icons.store,
                          label: "Tienda",
                          onTap: () => _goToTab(3),
                        ),
                        const SizedBox(height: 12),
                        _circleMenuButton(
                          icon: Icons.flag,
                          label: "Misiones",
                          onTap: () => _goToTab(4),
                        ),
                        const SizedBox(height: 12),
                        _circleMenuButton(
                          icon: Icons.person,
                          label: "Perfil",
                          onTap: () => _goToTab(5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGardenInventorySheet() {
    if (!isEditingGarden) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FutureBuilder<String?>(
            future: _coupleCodeFuture,
            builder: (context, codeSnapshot) {
              final coupleCode = codeSnapshot.data;

              if (codeSnapshot.connectionState == ConnectionState.waiting) {
                return _inventorySheetContainer(
                  child: const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (coupleCode == null || coupleCode.isEmpty) {
                return _inventorySheetContainer(
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Primero necesitas estar vinculado con tu pareja.',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _db.collection('couples').doc(coupleCode).get(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() ?? {};
                  final ownedItems = _ownedGardenItemsFromData(data);

                  final availableItems = gardenShopItems.where((item) {
                    if (item.isRealMoney || item.comingSoonPremium) {
                      return false;
                    }
                    if (item.type == 'house') return false;
                    if (game.placedCatalogItemIds.contains(item.id)) {
                      return false;
                    }

                    return item.isFree || ownedItems.contains(item.id);
                  }).toList();

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _inventorySheetContainer(
                      child: const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (availableItems.isEmpty) {
                    return _inventorySheetContainer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Aún no tienes objetos comprados 🛍️',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Compra decoración en la tienda y luego vuelve aquí para agregarla al jardín.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.58),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GardenShopScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.store),
                            label: const Text('Ir a tienda'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return _inventorySheetContainer(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _inventorySheetItem(
                              label: item.name,
                              icon: _iconForGardenItem(item.type),
                              onTap: () async {
                                Navigator.pop(sheetContext);

                                await _addGardenItem(
                                  catalogItemId: item.id,
                                  type: item.type,
                                  assetPath: item.assetPath,
                                  size: item.size,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _inventorySheetContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  IconData _iconForGardenItem(String type) {
    switch (type) {
      case 'pot':
        return Icons.local_florist;
      case 'flowers':
        return Icons.filter_vintage;
      case 'bush':
        return Icons.spa;
      case 'tree':
        return Icons.park;
      case 'special_plant':
        return Icons.eco;
      case 'table':
        return Icons.table_restaurant;
      default:
        return Icons.yard;
    }
  }

  Widget _inventorySheetItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8F3FF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 92,
          height: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.purple, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHouseSelectorSheet() {
    if (!isEditingGarden) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FutureBuilder<String?>(
            future: _coupleCodeFuture,
            builder: (context, codeSnapshot) {
              final coupleCode = codeSnapshot.data;

              if (codeSnapshot.connectionState == ConnectionState.waiting) {
                return _inventorySheetContainer(
                  child: const SizedBox(
                    height: 130,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (coupleCode == null || coupleCode.isEmpty) {
                return _inventorySheetContainer(
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Primero necesitas estar vinculado con tu pareja.',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _db.collection('couples').doc(coupleCode).get(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() ?? {};
                  final ownedItems = _ownedGardenItemsFromData(data);
                  final selectedHouseId =
                      data['selectedHouseId']?.toString() ?? 'house_basic';

                  final availableHouses = gardenShopItems.where((item) {
                    if (item.type != 'house') return false;
                    if (item.isRealMoney || item.comingSoonPremium) {
                      return false;
                    }

                    return item.isFree || ownedItems.contains(item.id);
                  }).toList();

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _inventorySheetContainer(
                      child: const SizedBox(
                        height: 130,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (availableHouses.isEmpty) {
                    return _inventorySheetContainer(
                      child: const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Todavía no tienes casas disponibles.',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }

                  return _inventorySheetContainer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(
                            'Elegir casa 🏡',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableHouses.map((item) {
                              final selected = item.id == selectedHouseId;

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _houseSelectorItem(
                                  item: item,
                                  selected: selected,
                                  onTap: () async {
                                    Navigator.pop(sheetContext);
                                    await _equipHouse(item);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _houseSelectorItem({
    required GardenShopItem item,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFEED7FF) : const Color(0xFFF8F3FF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Colors.purple : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 112,
                height: 78,
                child: Image.asset(
                  'assets/images/${item.assetPath}',
                  fit: BoxFit.contain,
                  cacheWidth: 336,
                  errorBuilder: (_, _, _) {
                    return Center(
                      child: Text(
                        item.emoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                const Text(
                  'Equipada',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, codeSnapshot) {
        final coupleCode = codeSnapshot.data;

        if (coupleCode == null || coupleCode.isEmpty) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('couples').doc(coupleCode).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};

            final coins = _toInt(data['coins'], 0);
            final love = _toInt(data['love'], 80);
            final energy = _toInt(data['energy'], 70);
            final plants = _toInt(data['plantsWatered'], 0);
            final plantData = data['gardenPlant'];
            final plantStage = plantData is Map
                ? _toInt(plantData['stage'], 1).clamp(1, 3)
                : 1;
            _syncVisiblePlantStage(plantStage);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _hudBadge("🪙", coins.toString()),
                const SizedBox(width: 8),
                _hudBadge("❤️", "$love%"),
                const SizedBox(width: 8),
                _hudBadge("⚡", "$energy%"),
                const SizedBox(width: 8),
                _hudBadge(
                  "🌱",
                  "${GardenInteractionPolicy.plantStageLabel(plantStage)} · $plants",
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _syncVisiblePlantStage(int stage) {
    final safeStage = stage.clamp(1, 3);
    if (_visiblePlantStage == safeStage) return;
    _visiblePlantStage = safeStage;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await game.loaded;
      await game.changeGardenPlantStage(safeStage);
    });
  }

  Widget _hudBadge(String icon, String value) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          "$icon $value",
          style: const TextStyle(
            color: Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _glassButton({required String text, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _editGardenButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.purple, size: 18),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 92,
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.purple, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
