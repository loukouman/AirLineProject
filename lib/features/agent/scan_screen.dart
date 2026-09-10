import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _processing = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      final pass = await SupabaseService.client
          .from('boarding_passes')
          .select('*, flights(*, airlines(name), gates(code)), profiles(full_name)')
          .eq('qr_code', code)
          .maybeSingle();

      if (pass == null) {
        setState(() => _error = 'Aucune carte d\'embarquement trouvée pour ce code.');
      } else {
        setState(() => _result = pass);
      }
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un embarquement')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(onDetect: _onDetect),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _processing
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                      : _result == null
                          ? const Center(child: Text('Scannez un QR code de carte d\'embarquement', style: TextStyle(color: AppColors.inkSoft)))
                          : _ResultCard(data: _result!),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final flight = data['flights'] as Map<String, dynamic>?;
    final profile = data['profiles'] as Map<String, dynamic>?;
    final airline = flight?['airlines'] as Map<String, dynamic>?;
    final gate = flight?['gates'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.appBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Carte valide', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Text(profile?['full_name'] as String? ?? 'Voyageur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${flight?['flight_number'] ?? ''} · ${airline?['name'] ?? ''}', style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Text('${flight?['origin_code'] ?? ''} → ${flight?['destination_code'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [
              Text('Siège : ${data['seat'] ?? '--'}'),
              Text('Groupe : ${data['boarding_group'] ?? '--'}'),
              Text('Porte : ${gate?['code'] ?? '--'}'),
            ]),
          ],
        ),
      ),
    );
  }
}
