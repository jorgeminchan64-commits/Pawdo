import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shop/data/interior_shop_items.dart';
import '../../shop/screens/interior_shop_screen.dart';
import '../../economy/services/economy_service.dart';
import '../../cinema/screens/pawdo_cinema_screen.dart';
import '../game/pawdo_interior_game.dart';
import '../models/interior_layout_policy.dart';
import '../../world/services/layout_service.dart';

class PawdoInteriorScreen extends StatefulWidget {
  const PawdoInteriorScreen({super.key});

  @override
  State<PawdoInteriorScreen> createState() => _PawdoInteriorScreenState();
}

class _PawdoInteriorScreenState extends State<PawdoInteriorScreen> {
  late final PawdoInteriorGame game;
  late final Future<String?> _coupleCodeFuture;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LayoutService _layoutService = LayoutService();

  bool isEditingInterior = false;
  bool _isSavingLayout = false;
  bool _hasUnsavedChanges = false;
  int _interiorRevision = 0;

  @override
  void initState() {
    super.initState();

    _coupleCodeFuture = _getCoupleCode();

    game = PawdoInteriorGame(
      onInteriorReward: _applyInteriorReward,
      onOpenCinema: _openCinema,
      onLayoutChanged: _markLayoutDirty,
    );

    _setLandscape();
    _loadInteriorLayoutFromFirebase();
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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

  Set<String> _ownedInteriorItemsFromData(Map<String, dynamic> data) {
    final rawOwned = data['ownedInteriorItems'];

    if (rawOwned is List) {
      return rawOwned.map((item) => item.toString()).toSet();
    }

    return {};
  }

  Future<void> _applyInteriorReward(Map<String, dynamic> reward) async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final actionText = reward['lastAction']?.toString().toLowerCase() ?? '';
    final actionId = actionText.contains('descansaron')
        ? 'interior_sleep'
        : actionText.contains('sentaron')
        ? 'interior_sit'
        : actionText.contains('comieron')
        ? 'interior_eat'
        : actionText.contains('película') || actionText.contains('pelicula')
        ? 'interior_movie'
        : actionText.contains('planta')
        ? 'interior_plant'
        : actionText.contains('pawdo')
        ? 'interior_pet'
        : actionText.contains('abrazo')
        ? 'interior_hug'
        : null;
    if (actionId == null) return;
    final serverResult = await EconomyService().performAction(
      coupleCode: coupleCode,
      actionId: actionId,
    );
    if (mounted && serverResult['alreadyClaimed'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta recompensa diaria ya fue reclamada hoy ✅'),
        ),
      );
    }
  }

  Future<void> _loadInteriorLayoutFromFirebase({bool notify = false}) async {
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    try {
      final doc = await _db.collection('couples').doc(coupleCode).get();
      final data = doc.data() ?? {};
      final layout = data['interiorLayout'];
      final revision = data['interiorRevision'];

      await game.loaded;
      await game.loadInteriorLayout(layout is List ? layout : const []);
      if (!mounted) return;
      setState(() {
        _interiorRevision = revision is num ? revision.toInt() : 0;
        _hasUnsavedChanges = false;
      });

      if (notify && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Interior recargado ✅')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el interior: $error')),
      );
    }
  }

  Future<void> _saveInteriorLayout() async {
    if (_isSavingLayout) return;
    final coupleCode = await _coupleCodeFuture;
    if (coupleCode == null || coupleCode.isEmpty) return;

    final layout = game.exportInteriorLayout();
    setState(() => _isSavingLayout = true);
    try {
      _interiorRevision = await _layoutService.saveSharedLayout(
        coupleCode: coupleCode,
        area: 'interior',
        layout: layout,
        expectedRevision: _interiorRevision,
      );
      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Interior guardado ✅')));
    } on LayoutException catch (error) {
      if (!mounted) return;
      if (error.code == 'aborted') {
        await _offerReloadAfterConflict(error.message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSavingLayout = false);
    }
  }

  Future<void> _offerReloadAfterConflict(String message) async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambios más recientes disponibles'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar los míos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
    if (reload != true || !mounted) return;
    setState(() => isEditingInterior = false);
    game.setInteriorEditMode(false);
    await _loadInteriorLayoutFromFirebase(notify: true);
  }

  void _toggleInteriorEditMode() {
    setState(() {
      isEditingInterior = !isEditingInterior;
    });

    game.setInteriorEditMode(isEditingInterior);
  }

  void _markLayoutDirty() {
    if (!mounted || _hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _addInteriorShopItem(InteriorShopItem item) async {
    final added = await game.addInteriorItemFromShop(
      catalogItemId: item.id,
      type: item.type,
      label: item.name,
      assetPath: item.assetPath,
      size: item.size,
    );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese mueble ya está colocado')),
      );
      return;
    }
    if (mounted) {
      final zone = InteriorLayoutPolicy.zoneLabel(item.type);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} listo en $zone. Guarda el cambio.'),
        ),
      );
    }
  }

  void _deleteSelectedInteriorItem() {
    final result = game.deleteSelectedInteriorItem();
    final message = switch (result) {
      InteriorDeleteResult.deleted => 'Mueble eliminado 🗑️',
      InteriorDeleteResult.protected =>
        'Este mueble esencial no se puede eliminar',
      InteriorDeleteResult.noSelection => 'Primero selecciona un mueble',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInteriorInventorySheet() {
    if (!isEditingInterior) return;

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
                return _sheetContainer(
                  child: const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (coupleCode == null || coupleCode.isEmpty) {
                return _sheetContainer(
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
                  final ownedItems = _ownedInteriorItemsFromData(data);

                  final availableItems = interiorShopItems.where((item) {
                    if (item.isRealMoney || item.comingSoonPremium) {
                      return false;
                    }
                    final unlocked =
                        item.isFree || ownedItems.contains(item.id);
                    return unlocked &&
                        !game.placedCatalogItemIds.contains(item.id);
                  }).toList();

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _sheetContainer(
                      child: const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (availableItems.isEmpty) {
                    return _sheetContainer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Aún no tienes muebles comprados 🛋️',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Compra muebles en la tienda interior y luego vuelve aquí para agregarlos.',
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
                                  builder: (_) => const InteriorShopScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.store),
                            label: const Text('Ir a tienda interior'),
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

                  return _sheetContainer(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _interiorSheetItem(
                              label: item.name,
                              icon: _iconForInteriorItem(item.type),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _addInteriorShopItem(item);
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

  IconData _iconForInteriorItem(String type) {
    switch (type) {
      case 'bed':
        return Icons.bed;
      case 'sofa':
        return Icons.weekend;
      case 'table':
        return Icons.table_restaurant;
      case 'tv':
        return Icons.tv;
      case 'plant':
        return Icons.spa;
      case 'lamp':
        return Icons.lightbulb;
      case 'rug':
        return Icons.crop_landscape;
      case 'pet_bed':
        return Icons.pets;
      default:
        return Icons.chair;
    }
  }

  Future<void> _openCinema() async {
    if (isEditingInterior) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PawdoCinemaScreen()),
    );
  }

  Future<void> _requestExit() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'Los cambios de decoración de esta sesión todavía no se guardaron.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar y salir'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _hasUnsavedChanges = false);
    Navigator.pop(context);
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
        if (!didPop) _requestExit();
      },
      child: FutureBuilder<String?>(
        future: _coupleCodeFuture,
        builder: (context, codeSnapshot) {
          final coupleCode = codeSnapshot.data;

          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: GameWidget(game: game)),

                Positioned(
                  top: 18,
                  left: 18,
                  child: SafeArea(
                    child: _topButton(
                      text: 'Volver',
                      icon: Icons.arrow_back,
                      onTap: _requestExit,
                    ),
                  ),
                ),

                Positioned(
                  top: 18,
                  left: 126,
                  child: SafeArea(
                    child: _topButton(
                      text: isEditingInterior ? 'Salir edición' : 'Editar',
                      icon: isEditingInterior ? Icons.close : Icons.edit,
                      onTap: _toggleInteriorEditMode,
                    ),
                  ),
                ),

                if (isEditingInterior)
                  Positioned(
                    top: 18,
                    left: 240,
                    child: SafeArea(
                      child: Row(
                        children: [
                          _topButton(
                            text: 'Agregar',
                            icon: Icons.add_circle,
                            onTap: _showInteriorInventorySheet,
                          ),
                          const SizedBox(width: 10),
                          _topButton(
                            text: 'Tienda',
                            icon: Icons.store,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InteriorShopScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          _topButton(
                            text: _isSavingLayout
                                ? 'Guardando...'
                                : _hasUnsavedChanges
                                ? 'Guardar *'
                                : 'Guardado',
                            icon: Icons.save,
                            onTap: _saveInteriorLayout,
                          ),
                          const SizedBox(width: 10),
                          _topButton(
                            text: 'Eliminar',
                            icon: Icons.delete,
                            onTap: _deleteSelectedInteriorItem,
                          ),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  top: 18,
                  right: 18,
                  child: SafeArea(
                    child: coupleCode == null || coupleCode.isEmpty
                        ? const SizedBox.shrink()
                        : _buildHud(coupleCode),
                  ),
                ),

                Positioned(
                  left: 18,
                  bottom: 18,
                  child: SafeArea(
                    child: isEditingInterior ? _editHintBox() : _hintBox(),
                  ),
                ),
                if (isEditingInterior)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: SafeArea(child: _zoneLegend()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHud(String coupleCode) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('couples').doc(coupleCode).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final coins = _toInt(data['coins'], 0);
        final love = _toInt(data['love'], 80);
        final energy = _toInt(data['energy'], 70);

        return Row(
          children: [
            _hudBadge('🪙', coins.toString()),
            const SizedBox(width: 8),
            _hudBadge('❤️', '$love%'),
            const SizedBox(width: 8),
            _hudBadge('⚡', '$energy%'),
          ],
        );
      },
    );
  }

  Widget _hudBadge(String icon, String value) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          '$icon $value',
          style: const TextStyle(
            color: Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _topButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(22),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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

  Widget _sheetContainer({required Widget child}) {
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

  Widget _interiorSheetItem({
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

  Widget _hintBox() {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          'Toca cama, sofá, mesa, TV, planta, Pawdo o personajes ✨',
          style: TextStyle(
            color: Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _editHintBox() {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          'Modo edición: toca un mueble, arrástralo y guarda ✅',
          style: TextStyle(
            color: Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _zoneLegend() {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          'Zonas sugeridas: Descanso · Sala · Mesa · Pawdo',
          style: TextStyle(
            color: Colors.purple,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
