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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedName = file.name;
    });
  }

  Future<void> _upload() async {
    if (_pickedBytes == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une image et un titre.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await SupabaseService.uploadAd(
        bytes: _pickedBytes!,
        fileName: _pickedName ?? 'ad.jpg',
        title: _titleController.text.trim(),
      );
      setState(() {
        _pickedBytes = null;
        _pickedName = null;
      });
      _titleController.clear();
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicité ajoutée.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter une publicité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),

          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                image: _pickedBytes != null
                    ? DecorationImage(image: MemoryImage(_pickedBytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: _pickedBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppColors.inkSoft, size: 32),
                          SizedBox(height: 6),
                          Text('Choisir une image', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                        ],
                      ),
                    )
                  : null,
            ),
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
                          child: Image.network(ad['image_url'] as String, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(isActive ? 'En ligne' : 'Retirée', style: TextStyle(fontSize: 10, color: isActive ? AppColors.success : AppColors.inkSoft)),
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
