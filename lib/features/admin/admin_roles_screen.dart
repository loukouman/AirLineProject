import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  static const _roles = ['voyageur', 'agent_enregistrement', 'agent_surete', 'admin'];
  static const _roleLabels = {
    'voyageur': 'Voyageur',
    'agent_enregistrement': 'Agent d\'enregistrement',
    'agent_surete': 'Agent de sûreté',
    'admin': 'Administrateur',
  };

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getAllProfiles();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getAllProfiles();
    });
  }

  Future<void> _changeRole(String userId, String newRole) async {
    try {
      await SupabaseService.updateUserRole(userId, newRole);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rôle mis à jour.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des rôles')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) {
            return const Center(child: Text('Aucun compte trouvé.', style: TextStyle(color: AppColors.inkSoft)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = profiles[i];
              final role = p['role'] as String? ?? 'voyageur';
              final isSelf = p['id'] == currentUserId;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 18, backgroundColor: AppColors.skyPale, child: Icon(Icons.person, color: AppColors.primary, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['full_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isSelf) const Text('(vous)', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: role,
                      underline: const SizedBox(),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(_roleLabels[r]!, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: isSelf ? null : (newRole) {
                        if (newRole != null) _changeRole(p['id'] as String, newRole);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
