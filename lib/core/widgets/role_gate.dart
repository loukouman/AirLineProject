import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'main_navigation.dart';
import '../../features/agent/checkin_desk_screen.dart';
import '../../features/agent/security_desk_screen.dart';

/// Route le voyageur connecté vers l'interface adaptée à son rôle.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<String> _futureRole;

  @override
  void initState() {
    super.initState();
    _futureRole = SupabaseService.getMyRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _futureRole,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        switch (snapshot.data) {
          case 'agent_enregistrement':
            return const CheckinDeskScreen();
          case 'agent_surete':
            return const SecurityDeskScreen();
          default:
            // 'voyageur' et 'admin' utilisent l'app voyageur classique
            // (l'admin accède à son espace via le bouton dans Profil).
            return const MainNavigation();
        }
      },
    );
  }
}
