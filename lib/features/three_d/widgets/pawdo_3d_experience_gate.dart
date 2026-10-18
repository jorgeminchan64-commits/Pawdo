import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/pawdo_3d_scene.dart';
import '../services/pawdo_unity_runtime_service.dart';

class Pawdo3DExperienceGate extends StatefulWidget {
  const Pawdo3DExperienceGate({
    required this.scene,
    required this.legacyBuilder,
    this.runtimeService = const PawdoUnityRuntimeService(),
    this.featurePolicy,
    super.key,
  });

  final Pawdo3DScene scene;
  final WidgetBuilder legacyBuilder;
  final PawdoUnityRuntimeService runtimeService;
  final Pawdo3DFeaturePolicy? featurePolicy;

  @override
  State<Pawdo3DExperienceGate> createState() => _Pawdo3DExperienceGateState();
}

class _Pawdo3DExperienceGateState extends State<Pawdo3DExperienceGate>
    with WidgetsBindingObserver {
  bool _nativeRuntimeLaunched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final policy =
        widget.featurePolicy ??
        Pawdo3DFeaturePolicy.fromEnvironment(
          androidRuntime: defaultTargetPlatform == TargetPlatform.android,
        );
    if (policy.canLaunch(widget.scene)) {
      _tryLaunch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _nativeRuntimeLaunched &&
        mounted) {
      setState(() => _nativeRuntimeLaunched = false);
    }
  }

  Future<void> _tryLaunch() async {
    final capabilities = await widget.runtimeService.capabilities();
    if (!mounted ||
        !capabilities.available ||
        capabilities.bridgeSchemaVersion != 1) {
      return;
    }
    final launched = await widget.runtimeService.launch(widget.scene);
    if (mounted && launched) {
      setState(() => _nativeRuntimeLaunched = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_nativeRuntimeLaunched) {
      return widget.legacyBuilder(context);
    }
    return const ColoredBox(
      color: Color(0xFF1F2024),
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
