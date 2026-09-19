import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  late Future<int> _futurePoints;
  late Future<List<Map<String, dynamic>>> _futureHistory;
  StreamSubscription<List<Map<String, dynamic>>>? _watchSub;

  // Seuils de niveau : simples et lisibles pour une v1.
  static const _silverThreshold = 300;
  static const _goldThreshold = 800;

  @override
  void initState() {
    super.initState();
    _futurePoints = SupabaseService.getMyLoyaltyPoints();
    _futureHistory = SupabaseService.getMyLoyaltyHistory();

    _watchSub = SupabaseService.watchMyLoyaltyPoints().listen((_) {
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
      _futurePoints = SupabaseService.getMyLoyaltyPoints();
      _futureHistory = SupabaseService.getMyLoyaltyHistory();
    });
  }

  String _tierName(int points) {
    if (points >= _goldThreshold) return 'Or';
    if (points >= _silverThreshold) return 'Argent';
    return 'Bronze';
  }

  Color _tierColor(int points) {
    if (points >= _goldThreshold) return const Color(0xFFC9A227);
    if (points >= _silverThreshold) return const Color(0xFF9AA5B1);
    return const Color(0xFFB0733E);
  }

  IconData _tierIcon(int points) {
    if (points >= _goldThreshold) return Icons.emoji_events;
    if (points >= _silverThreshold) return Icons.workspace_premium;
    return Icons.military_tech;
  }

  ({int nextThreshold, String nextTierName})? _nextTier(int points) {
    if (points < _silverThreshold) return (nextThreshold: _silverThreshold, nextTierName: 'Argent');
    if (points < _goldThreshold) return (nextThreshold: _goldThreshold, nextTierName: 'Or');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fidélité')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<int>(
          future: _futurePoints,
          builder: (context, pointsSnapshot) {
            final points = pointsSnapshot.data ?? 0;
            final tierColor = _tierColor(points);
            final nextTier = _nextTier(points);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tierColor, tierColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: tierColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_tierIcon(points), color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Text('Niveau ${_tierName(points)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('$points points', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      if (nextTier != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (points / nextTier.nextThreshold).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${nextTier.nextThreshold - points} points avant le niveau ${nextTier.nextTierName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ] else
                        const Text('Niveau maximum atteint — merci pour votre fidélité !', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                const Text('Avantages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                _PerkTile(icon: Icons.local_parking, title: 'Bronze', description: 'Accès au programme, 100 points par vol effectué'),
                _PerkTile(icon: Icons.fastfood_outlined, title: 'Argent (300 pts)', description: 'Réduction sur les boutiques et restaurants partenaires'),
                _PerkTile(icon: Icons.workspace_premium, title: 'Or (800 pts)', description: 'Priorité au comptoir enregistrement, assistance dédiée'),

                const SizedBox(height: 22),
                const Text('Historique récent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureHistory,
                  builder: (context, snapshot) {
                    final history = snapshot.data ?? [];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (history.isEmpty) {
                      return const Text('Aucun point gagné pour le moment. Vole avec nous pour commencer !', style: TextStyle(color: AppColors.inkSoft, fontSize: 12));
                    }

                    return Column(
                      children: history.map((h) {
                        final createdAt = DateTime.parse(h['created_at'] as String);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF3F7FA), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, color: AppColors.success, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h['reason'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt), style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                              Text('+${h['points']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PerkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _PerkTile({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF3F7FA), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(description, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
