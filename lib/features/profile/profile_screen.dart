import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../admin/admin_screen.dart';
import '../loyalty/loyalty_screen.dart';
import '../../core/services/data_saver_service.dart';
import '../vault/document_vault_screen.dart';

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
            const SizedBox(height: 20),

            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoyaltyScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech, color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Programme de fidélité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Voir mes points et avantages', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

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

            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocumentVaultScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Coffre-fort documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Passeport, CNI, visa, vaccination...', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.inkSoft, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Mode économe en données', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'Réduit la consommation de données (les vidéos publicitaires ne se chargent pas automatiquement).',
              style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: DataSaverService.mode,
              builder: (context, currentMode, _) {
                return Row(
                  children: [
                    Expanded(child: _ModeChip(label: 'Auto', selected: currentMode == 'auto', onTap: () => DataSaverService.setMode('auto'))),
                    const SizedBox(width: 8),
                    Expanded(child: _ModeChip(label: 'Activé', selected: currentMode == 'on', onTap: () => DataSaverService.setMode('on'))),
                    const SizedBox(width: 8),
                    Expanded(child: _ModeChip(label: 'Désactivé', selected: currentMode == 'off', onTap: () => DataSaverService.setMode('off'))),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

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

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : Colors.black.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textDark),
        ),
      ),
    );
  }
}
