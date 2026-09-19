import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _uploading = false;

  static const _docTypes = {
    'passeport': 'Passeport',
    'cni': 'Carte d\'identité',
    'visa': 'Visa',
    'vaccination': 'Carnet de vaccination',
    'autre': 'Autre document',
  };

  static const _docIcons = {
    'passeport': Icons.menu_book_outlined,
    'cni': Icons.badge_outlined,
    'visa': Icons.assignment_outlined,
    'vaccination': Icons.vaccines_outlined,
    'autre': Icons.description_outlined,
  };

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMyTravelDocuments();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getMyTravelDocuments();
    });
  }

  Future<void> _addDocument() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    String docType = 'passeport';
    final labelController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type de document', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: docType,
                isExpanded: true,
                items: _docTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setDialogState(() => docType = v ?? 'passeport'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'Nom (ex: Passeport - validité 2030)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: labelController.text.trim().isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || labelController.text.trim().isEmpty) return;

    setState(() => _uploading = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      await SupabaseService.addTravelDocument(
        bytes: bytes,
        fileName: file.name,
        docType: docType,
        label: labelController.text.trim(),
      );
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document ajouté au coffre-fort.')));
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

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    try {
      final url = await SupabaseService.getTravelDocumentSignedUrl(doc['file_path'] as String);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    doc['label'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(200),
                    child: Image.network(
                      url,
                      fit: BoxFit.fitHeight,
                      height: double.infinity,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.inkSoft),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Glisse pour voir les côtés · pince pour zoomer', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'afficher le document : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${doc['label']} » sera définitivement supprimé du coffre-fort.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.deleteTravelDocument(doc['id'] as String, doc['file_path'] as String);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coffre-fort documents')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F7FA), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tes documents sont stockés de façon privée et accessibles uniquement par toi.',
                    style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(60),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_outlined, size: 56, color: AppColors.inkSoft),
                              SizedBox(height: 16),
                              Text('Aucun document pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final docType = doc['doc_type'] as String? ?? 'autre';

                      return InkWell(
                        onTap: () => _viewDocument(doc),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.skyPale, borderRadius: BorderRadius.circular(10)),
                                child: Icon(_docIcons[docType] ?? Icons.description_outlined, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doc['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(_docTypes[docType] ?? docType, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteDocument(doc),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _addDocument,
        backgroundColor: AppColors.primary,
        child: _uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
