import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../admin/admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<String> _futureRole;
  late Future<String?> _futureAvatar;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _futureRole = SupabaseService.getMyRole();
    _futureAvatar = SupabaseService.getMyAvatarUrl();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      await SupabaseService.uploadMyAvatar(bytes, file.name);
      setState(() {
        _futureAvatar = SupabaseService.getMyAvatarUrl();
      });
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

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Voyageur';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<String?>(
                  future: _futureAvatar,
                  builder: (context, snapshot) {
                    final url = snapshot.data;
                    return GestureDetector(
                      onTap: _uploading ? null : _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.skyPale,
                            backgroundImage: url != null ? NetworkImage(url) : null,
                            child: url == null
                                ? const Icon(Icons.person, color: AppColors.primary, size: 30)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: _uploading
                                  ? const SizedBox(
                                      width: 12, height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(email, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            FutureBuilder<String>(
              future: _futureRole,
              builder: (context, snapshot) {
                if (snapshot.data != 'admin') return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen()));
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
                        label: const Text('Espace administrateur', style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await SupabaseService.signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
