import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/location_sharing_service.dart';

class LocationSharingStatusBanner extends StatefulWidget {
  const LocationSharingStatusBanner({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<LocationSharingStatusBanner> createState() =>
      _LocationSharingStatusBannerState();
}

class _LocationSharingStatusBannerState
    extends State<LocationSharingStatusBanner> {
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream =
      _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
  String? _shareCode;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _shareStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _streamFor(String code) {
    if (_shareCode != code || _shareStream == null) {
      _shareCode = code;
      _shareStream = FirebaseFirestore.instance
          .collection('couples')
          .doc(code)
          .collection('locationShares')
          .doc(_uid)
          .snapshots();
    }
    return _shareStream!;
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _userStream == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final code = userSnapshot.data?.data()?['coupleCode']?.toString() ?? '';
        if (code.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _streamFor(code),
          builder: (context, shareSnapshot) {
            final document = shareSnapshot.data;
            if (document == null || !document.exists) {
              return const SizedBox.shrink();
            }
            final share = LocationShare.fromDocument(document);
            if (!share.active || share.expired) return const SizedBox.shrink();
            return _ActiveShareBanner(share: share, onOpen: widget.onOpen);
          },
        );
      },
    );
  }
}

class _ActiveShareBanner extends StatefulWidget {
  const _ActiveShareBanner({required this.share, required this.onOpen});

  final LocationShare share;
  final VoidCallback onOpen;

  @override
  State<_ActiveShareBanner> createState() => _ActiveShareBannerState();
}

class _ActiveShareBannerState extends State<_ActiveShareBanner> {
  bool _stopping = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(covariant _ActiveShareBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.share.expiresAt != widget.share.expiresAt) _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiry = widget.share.expiresAt;
    if (expiry == null) return;
    final remaining = expiry.difference(DateTime.now());
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    try {
      await LocationSharingService.instance.stop();
    } on LocationSharingException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.share.expired) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFDFF5E8),
      child: SafeArea(
        top: false,
        bottom: false,
        child: InkWell(
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF267B52)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Compartiendo ubicación',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${_modeLabel(widget.share.mode)} · '
                        '${widget.share.approximate ? 'aproximada' : 'precisa'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _stopping ? null : _stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_stopping ? 'Deteniendo…' : 'Detener'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _modeLabel(String mode) => switch (mode) {
  '15m' => '15 min',
  '1h' => '1 h',
  '8h' => '8 h',
  'until_stopped' => 'hasta detener',
  _ => 'temporal',
};
