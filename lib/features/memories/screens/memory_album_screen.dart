import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/memory_entry.dart';
import '../services/memory_service.dart';

enum _AlbumView { grid, timeline }

class MemoryAlbumScreen extends StatefulWidget {
  const MemoryAlbumScreen({super.key});

  @override
  State<MemoryAlbumScreen> createState() => _MemoryAlbumScreenState();
}

class _MemoryAlbumScreenState extends State<MemoryAlbumScreen> {
  final MemoryService _service = MemoryService();
  _AlbumView _view = _AlbumView.grid;
  bool _saving = false;
  double _progress = 0;

  Future<void> _add(String coupleCode) async {
    final form = await showModalBottomSheet<_MemoryFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MemoryForm(),
    );
    if (form == null || !mounted) return;
    setState(() {
      _saving = true;
      _progress = 0;
    });
    try {
      await _service.create(
        coupleCode: coupleCode,
        description: form.description,
        date: form.date,
        place: form.place,
        tags: form.tags,
        category: form.category,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
    } on MemoryException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, profile) {
        final code = profile.data?.data()?['coupleCode']?.toString() ?? '';
        if (code.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Conecta a tu pareja para crear su álbum.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Álbum de recuerdos'),
            actions: [
              SegmentedButton<_AlbumView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _AlbumView.grid,
                    icon: Icon(Icons.grid_view_rounded),
                  ),
                  ButtonSegment(
                    value: _AlbumView.timeline,
                    icon: Icon(Icons.view_timeline_rounded),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (value) =>
                    setState(() => _view = value.first),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _saving ? null : () => _add(code),
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Recuerdo'),
          ),
          body: Column(
            children: [
              if (_saving)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _service.watch(code),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('No se pudo cargar el álbum.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final memories = snapshot.data!.docs
                        .map(MemoryEntry.fromDocument)
                        .toList(growable: false);
                    if (memories.isEmpty) return const _EmptyAlbum();
                    return _view == _AlbumView.grid
                        ? _MemoryGrid(
                            memories: memories,
                            service: _service,
                            coupleCode: code,
                            uid: uid,
                          )
                        : _MemoryTimeline(
                            memories: memories,
                            service: _service,
                            coupleCode: code,
                            uid: uid,
                          );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemoryGrid extends StatelessWidget {
  const _MemoryGrid({
    required this.memories,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final List<MemoryEntry> memories;
  final MemoryService service;
  final String coupleCode;
  final String uid;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: .78,
    ),
    itemCount: memories.length,
    itemBuilder: (context, index) => _MemoryCard(
      memory: memories[index],
      service: service,
      coupleCode: coupleCode,
      uid: uid,
    ),
  );
}

class _MemoryTimeline extends StatelessWidget {
  const _MemoryTimeline({
    required this.memories,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final List<MemoryEntry> memories;
  final MemoryService service;
  final String coupleCode;
  final String uid;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
    itemCount: memories.length,
    itemBuilder: (context, index) {
      final memory = memories[index];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _formatMemoryDate(memory.date),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.favorite_rounded, size: 18, color: Colors.pink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _MemoryCard(
                memory: memory,
                service: service,
                coupleCode: coupleCode,
                uid: uid,
                timeline: true,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.service,
    required this.coupleCode,
    required this.uid,
    this.timeline = false,
  });
  final MemoryEntry memory;
  final MemoryService service;
  final String coupleCode;
  final String uid;
  final bool timeline;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _MemoryDetail(
            memory: memory,
            service: service,
            coupleCode: coupleCode,
            uid: uid,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: timeline ? 0 : 1,
            child: SizedBox(
              height: timeline ? 190 : null,
              width: double.infinity,
              child: _MemoryImage(
                service: service,
                path: memory.thumbnailPath,
                maxBytes: MemoryService.maxThumbnailBytes,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory.description.isEmpty
                            ? memory.categoryLabel
                            : memory.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        memory.categoryLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Favorito',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => service.toggleFavorite(
                    coupleCode: coupleCode,
                    memoryId: memory.id,
                  ),
                  icon: Icon(
                    memory.isFavoriteFor(uid)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: Colors.pink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MemoryDetail extends StatelessWidget {
  const _MemoryDetail({
    required this.memory,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final MemoryEntry memory;
  final MemoryService service;
  final String coupleCode;
  final String uid;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(memory.categoryLabel),
      actions: [
        IconButton(
          onPressed: () => service.toggleFavorite(
            coupleCode: coupleCode,
            memoryId: memory.id,
          ),
          icon: Icon(
            memory.isFavoriteFor(uid)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
          ),
        ),
        if (memory.createdBy == uid)
          IconButton(
            tooltip: 'Eliminar recuerdo',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar recuerdo'),
                  content: const Text(
                    'Se eliminará la foto para ambos integrantes.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              await service.delete(coupleCode: coupleCode, memoryId: memory.id);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: InteractiveViewer(
            child: _MemoryImage(
              service: service,
              path: memory.originalPath,
              maxBytes: MemoryService.maxOriginalBytes,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                memory.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '${_formatMemoryDate(memory.date)}${memory.place.isEmpty ? '' : ' · ${memory.place}'}',
              ),
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: memory.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _MemoryImage extends StatelessWidget {
  const _MemoryImage({
    required this.service,
    required this.path,
    required this.maxBytes,
  });
  final MemoryService service;
  final String path;
  final int maxBytes;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: service.loadImage(path, maxBytes: maxBytes),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Container(
          color: Colors.pink.shade50,
          child: Center(
            child: snapshot.hasError
                ? const Icon(Icons.broken_image_outlined)
                : const CircularProgressIndicator(),
          ),
        );
      }
      return Image.memory(
        snapshot.data!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    },
  );
}

class _MemoryFormData {
  const _MemoryFormData({
    required this.description,
    required this.date,
    required this.place,
    required this.tags,
    required this.category,
  });
  final String description;
  final DateTime date;
  final String place;
  final List<String> tags;
  final MemoryCategory category;
}

class _MemoryForm extends StatefulWidget {
  const _MemoryForm();
  @override
  State<_MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<_MemoryForm> {
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _tags = TextEditingController();
  DateTime _date = DateTime.now();
  MemoryCategory _category = MemoryCategory.special;

  @override
  void dispose() {
    _description.dispose();
    _place.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nuevo recuerdo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            TextField(
              controller: _place,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Lugar (opcional)'),
            ),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Etiquetas separadas por coma',
              ),
            ),
            DropdownButtonFormField<MemoryCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: MemoryCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        MemoryEntry(
                          id: '',
                          description: '',
                          date: _date,
                          place: '',
                          tags: const [],
                          category: value,
                          createdBy: '',
                          favoriteBy: const {},
                          originalPath: '',
                          thumbnailPath: '',
                        ).categoryLabel,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha'),
              subtitle: Text(_formatMemoryDate(_date)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDate: _date,
                );
                if (selected != null) setState(() => _date = selected);
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _MemoryFormData(
                  description: _description.text.trim(),
                  date: _date,
                  place: _place.text.trim(),
                  tags: _tags.text.split(','),
                  category: _category,
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir foto y guardar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyAlbum extends StatelessWidget {
  const _EmptyAlbum();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_album_outlined, size: 62),
          SizedBox(height: 12),
          Text(
            'Su historia empieza aquí',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Agreguen una foto con fecha, lugar y etiquetas.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

String _formatMemoryDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
