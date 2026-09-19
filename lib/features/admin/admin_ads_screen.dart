import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  final _titleController = TextEditingController();
  Uint8List? _pickedBytes;
  String? _pickedName;
  List<Uint8List>? _pickedSegments;
  List<String>? _pickedSegmentNames;
  String _mediaType = 'image';
  bool _uploading = false;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getAllAds();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getAllAds();
    });
  }

  void _resetPicked() {
    _pickedBytes = null;
    _pickedName = null;
    _pickedSegments = null;
    _pickedSegmentNames = null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _resetPicked();
      _pickedBytes = bytes;
      _pickedName = file.name;
      _mediaType = 'image';
    });
  }

  /// Un seul bouton vidéo : l'agent peut choisir UNE vidéo (publiée telle
  /// quelle) ou PLUSIEURS (jouées bout à bout comme un statut) — le choix
  /// se fait naturellement selon le nombre de fichiers sélectionnés dans
  /// le même sélecteur, sans bouton séparé à gérer.
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia();
    if (files.isEmpty) return;

    if (files.length == 1) {
      final bytes = await files.first.readAsBytes();
      setState(() {
        _resetPicked();
        _pickedBytes = bytes;
        _pickedName = files.first.name;
        _mediaType = 'video';
      });
    } else {
      final segments = <Uint8List>[];
      final names = <String>[];
      for (final file in files) {
        segments.add(await file.readAsBytes());
        names.add(file.name);
      }
      setState(() {
        _resetPicked();
        _pickedSegments = segments;
        _pickedSegmentNames = names;
        _mediaType = 'video';
      });
    }
  }

  String _friendlyUploadError(Object e) {
    if (e is TimeoutException) {
      return "L'envoi a pris trop de temps — ta connexion est probablement trop lente pour ce fichier. Essaie en Wi-Fi, ou choisis une vidéo plus légère.";
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('exceeded') || msg.contains('too large') || msg.contains('payload') || msg.contains('413')) {
      return 'Ce fichier dépasse la limite du serveur (50 Mo). Choisis plusieurs vidéos plus courtes pour un contenu plus long.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return "Connexion internet instable pendant l'envoi. Réessaie, de préférence en Wi-Fi.";
    }
    return 'Erreur : $e';
  }

  Future<void> _upload() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute un titre.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_pickedBytes == null && (_pickedSegments == null || _pickedSegments!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un média.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      const uploadTimeout = Duration(minutes: 3);
      if (_pickedSegments != null && _pickedSegments!.isNotEmpty) {
        await SupabaseService.uploadAdSegments(
          segments: _pickedSegments!,
          fileNames: _pickedSegmentNames!,
          title: _titleController.text.trim(),
        ).timeout(uploadTimeout);
      } else {
        await SupabaseService.uploadAd(
          bytes: _pickedBytes!,
          fileName: _pickedName ?? (_mediaType == 'video' ? 'ad.mp4' : 'ad.jpg'),
          title: _titleController.text.trim(),
          mediaType: _mediaType,
        ).timeout(uploadTimeout);
      }
      setState(() {
        _resetPicked();
        _mediaType = 'image';
      });
      _titleController.clear();
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicité ajoutée.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyUploadError(e)), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(String id, String imageUrl) async {
    await SupabaseService.deleteAd(id, imageUrl);
    _refresh();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPicked = _pickedBytes != null || (_pickedSegments?.isNotEmpty ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter une publicité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mediaType == 'image' && _pickedBytes != null ? AppColors.primary : AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Vidéo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mediaType == 'video' && hasPicked ? AppColors.primary : AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              image: _pickedBytes != null && _mediaType == 'image'
                  ? DecorationImage(image: MemoryImage(_pickedBytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: !hasPicked
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.inkSoft, size: 32),
                        SizedBox(height: 6),
                        Text('Choisis une photo ou une/plusieurs vidéo(s)', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                      ],
                    ),
                  )
                : (_pickedSegments != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.video_library, color: AppColors.primary, size: 32),
                            const SizedBox(height: 6),
                            Text('${_pickedSegments!.length} parties sélectionnées', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                          ],
                        ),
                      )
                    : (_mediaType == 'video'
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam, color: AppColors.primary, size: 32),
                                const SizedBox(height: 6),
                                Text(_pickedName ?? 'Vidéo sélectionnée', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                              ],
                            ),
                          )
                        : null)),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titre affiché sur la publicité', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _uploading ? null : _upload,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _uploading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publier'),
            ),
          ),

          const SizedBox(height: 26),
          const Text('Publicités en ligne', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              final ads = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
              }
              if (ads.isEmpty) {
                return const Text('Aucune publicité pour le moment.', style: TextStyle(color: AppColors.inkSoft));
              }

              return Column(
                children: ads.map((ad) {
                  final isActive = ad['is_active'] as bool? ?? true;
                  final mediaType = ad['media_type'] as String? ?? 'image';
                  final segCount = (ad['media_urls'] as List<dynamic>?)?.length ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: mediaType == 'video'
                              ? Container(
                                  width: 56,
                                  height: 56,
                                  color: AppColors.skyPale,
                                  child: Icon(segCount > 1 ? Icons.video_library : Icons.videocam, color: AppColors.primary),
                                )
                              : Image.network(ad['image_url'] as String, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Row(
                                children: [
                                  Icon(mediaType == 'video' ? Icons.videocam : Icons.image, size: 11, color: AppColors.inkSoft),
                                  const SizedBox(width: 3),
                                  Text(
                                    isActive ? (segCount > 1 ? 'En ligne · $segCount parties' : 'En ligne') : 'Retirée',
                                    style: TextStyle(fontSize: 10, color: isActive ? AppColors.success : AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _delete(ad['id'] as String, ad['image_url'] as String),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
