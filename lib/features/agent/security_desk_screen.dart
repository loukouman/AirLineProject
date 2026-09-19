import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import 'incident_history_screen.dart';

class SecurityDeskScreen extends StatefulWidget {
  const SecurityDeskScreen({super.key});

  @override
  State<SecurityDeskScreen> createState() => _SecurityDeskScreenState();
}

class _SecurityDeskScreenState extends State<SecurityDeskScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  StreamSubscription<List<Map<String, dynamic>>>? _watchSub;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getSecurityZones();
    _watchSub = SupabaseService.watchSecurityZonesRaw().listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getSecurityZones();
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bonjour';
    if (hour >= 12 && hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  Future<void> _adjustWait(String zoneId, int currentMinutes, int delta) async {
    final updated = (currentMinutes + delta).clamp(0, 999);
    await SupabaseService.updateSecurityZoneWait(zoneId, updated);
    _refresh();
  }

  Future<void> _editExact(String zoneId, int currentMinutes) async {
    final controller = TextEditingController(text: currentMinutes.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temps d\'attente (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? currentMinutes),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      await SupabaseService.updateSecurityZoneWait(zoneId, result);
      _refresh();
    }
  }

  Future<void> _reportIncident({String? zoneId, String? zoneName}) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String severity = 'moyenne';
    Uint8List? photoBytes;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(
            zoneName != null ? 'Signaler un incident · $zoneName' : 'Signaler un incident',
            style: const TextStyle(fontSize: 17),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Objet / situation', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description (optionnel)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  const Text('Gravité', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SeverityOption(
                          label: 'Faible',
                          color: AppColors.success,
                          selected: severity == 'faible',
                          onTap: () => setDialogState(() => severity = 'faible'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SeverityOption(
                          label: 'Moyenne',
                          color: Colors.orange,
                          selected: severity == 'moyenne',
                          onTap: () => setDialogState(() => severity = 'moyenne'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SeverityOption(
                          label: 'Élevée',
                          color: Colors.redAccent,
                          selected: severity == 'elevee',
                          onTap: () => setDialogState(() => severity = 'elevee'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                            if (file != null) {
                              final bytes = await file.readAsBytes();
                              setDialogState(() => photoBytes = bytes);
                            }
                          },
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: Text(photoBytes == null ? 'Ajouter une photo' : 'Photo ajoutée ✓', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: titleController.text.trim().isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      try {
        await SupabaseService.reportSecurityIncident(
          zoneId: zoneId,
          title: titleController.text.trim(),
          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          severity: severity,
          photoBytes: photoBytes,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incident signalé.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec du signalement : \$e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Color _colorForWait(int wait) {
    if (wait <= 10) return AppColors.success;
    if (wait <= 20) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Agent';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones de sûreté'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des incidents',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncidentHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async { await SupabaseService.signOut(); },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final zones = snapshot.data ?? [];
          final worstWait = zones.isEmpty
              ? 0
              : zones.map((z) => z['estimated_wait_minutes'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
          final allFluid = zones.isNotEmpty && worstWait <= 10;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: allFluid
                          ? [AppColors.success, const Color(0xFF1F7A4D)]
                          : [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, $firstName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              allFluid ? 'Toutes les zones sont fluides !' : 'Zone la plus chargée : $worstWait min',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Icon(allFluid ? Icons.verified_outlined : Icons.shield_outlined, color: Colors.white70, size: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...zones.map((z) {
                  final zoneId = z['id'] as String;
                  final wait = z['estimated_wait_minutes'] as int? ?? 0;
                  final color = _colorForWait(wait);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(z['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${z['open_lanes'] ?? 0} file(s) ouverte(s)', style: const TextStyle(color: AppColors.inkSoft, fontSize: 11)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _editExact(zoneId, wait),
                              child: Text('$wait min', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _WaitButton(icon: Icons.remove, onTap: () => _adjustWait(zoneId, wait, -5), color: color),
                            const SizedBox(width: 8),
                            _WaitButton(icon: Icons.remove, small: true, onTap: () => _adjustWait(zoneId, wait, -1), color: color),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _reportIncident(zoneId: zoneId, zoneName: z['name'] as String?),
                              icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16, color: Colors.redAccent),
                              label: const Text('Signaler', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            ),
                            const Spacer(),
                            _WaitButton(icon: Icons.add, small: true, onTap: () => _adjustWait(zoneId, wait, 1), color: color),
                            const SizedBox(width: 8),
                            _WaitButton(icon: Icons.add, onTap: () => _adjustWait(zoneId, wait, 5), color: color),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _reportIncident(),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.report_gmailerrorred_outlined),
        label: const Text('Signaler un incident'),
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _SeverityOption({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.black.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textDark),
        ),
      ),
    );
  }
}

class _WaitButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool small;
  const _WaitButton({required this.icon, required this.onTap, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 30.0 : 36.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: small ? 14 : 18, color: color),
      ),
    );
  }
}
