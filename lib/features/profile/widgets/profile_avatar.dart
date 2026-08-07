import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.radius,
    this.storagePath,
    this.localFile,
    this.showEditBadge = false,
  });

  final double radius;
  final String? storagePath;
  final File? localFile;
  final bool showEditBadge;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.localFile?.path != widget.localFile?.path) {
      _prepare();
    }
  }

  void _prepare() {
    final path = widget.storagePath;
    _bytes = widget.localFile == null && path != null && path.isNotEmpty
        ? _load(path)
        : null;
  }

  Future<Uint8List?> _load(String path) async {
    try {
      return await FirebaseStorage.instance.ref(path).getData(1024 * 1024);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.localFile;
    if (file != null) return _frame(FileImage(file));
    if (_bytes == null) return _frame(null);
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) =>
          _frame(snapshot.data == null ? null : MemoryImage(snapshot.data!)),
    );
  }

  Widget _frame(ImageProvider<Object>? image) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.white,
          backgroundImage: image,
          child: image == null
              ? Icon(
                  Icons.person_rounded,
                  size: widget.radius,
                  color: const Color(0xFF7B3FA3),
                )
              : null,
        ),
        if (widget.showEditBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: CircleAvatar(
              radius: widget.radius * 0.28,
              backgroundColor: const Color(0xFF7B3FA3),
              child: Icon(
                Icons.camera_alt_rounded,
                size: widget.radius * 0.28,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
