import 'package:flutter/material.dart';

import '../services/network_recovery_service.dart';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key, this.service});

  final NetworkRecoveryService? service;

  @override
  Widget build(BuildContext context) {
    final recovery = service ?? NetworkRecoveryService.instance;
    return StreamBuilder<NetworkRecoveryStatus>(
      stream: recovery.statuses,
      initialData: recovery.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkRecoveryStatus.reconnecting;
        final visible = status != NetworkRecoveryStatus.online;
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: visible
              ? _StatusContent(status: status)
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({required this.status});

  final NetworkRecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, background, foreground) = switch (status) {
      NetworkRecoveryStatus.offline => (
        Icons.cloud_off_rounded,
        'Sin conexión',
        const Color(0xffffe9ec),
        const Color(0xff8f2336),
      ),
      NetworkRecoveryStatus.reconnecting => (
        Icons.sync_rounded,
        'Reconectando…',
        const Color(0xfffff3d8),
        const Color(0xff7a5200),
      ),
      NetworkRecoveryStatus.updated => (
        Icons.cloud_done_rounded,
        'Actualizado',
        const Color(0xffe5f6eb),
        const Color(0xff22633a),
      ),
      NetworkRecoveryStatus.online => (
        Icons.cloud_done_rounded,
        '',
        Colors.transparent,
        Colors.transparent,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: ColoredBox(
        color: background,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
