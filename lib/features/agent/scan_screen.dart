import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scannerController = MobileScannerController();
  final _searchController = TextEditingController();

  bool _processing = false;
  bool _locked = false; // Empêche de ré-enchaîner sur le même code tant que l'agent n'a pas relancé.
  Map<String, dynamic>? _result;
  String? _error;

  bool _searchMode = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _locked) return;
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
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'Aucune carte d\'embarquement trouvée pour ce code.';
          _locked = true;
        });
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        setState(() {
          _result = pass;
          _locked = true;
        });
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Erreur : $e';
        _locked = true;
      });
    } finally {
      setState(() => _processing = false);
    }
  }

  void _scanNext() {
    setState(() {
      _locked = false;
      _result = null;
      _error = null;
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final results = await SupabaseService.searchCheckins(query);
      setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> pass) {
    setState(() {
      _result = pass;
      _error = null;
      _locked = true;
      _searchMode = false;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un embarquement'),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.qr_code_scanner : Icons.search),
            tooltip: _searchMode ? 'Revenir au scan' : 'Recherche manuelle',
            onPressed: () => setState(() => _searchMode = !_searchMode),
          ),
        ],
      ),
      body: _searchMode ? _buildSearchMode() : _buildScanMode(),
    );
  }

  Widget _buildSearchMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Si le QR code ne scanne pas, cherche le voyageur par nom ou par siège.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nom du voyageur ou n° de siège…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _runSearch,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(child: Text('Aucun résultat.', style: TextStyle(color: AppColors.inkSoft)))
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final pass = _searchResults[i];
                      final flight = pass['flights'] as Map<String, dynamic>?;
                      final profile = pass['profiles'] as Map<String, dynamic>?;
                      return InkWell(
                        onTap: () => _selectSearchResult(pass),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(profile?['full_name'] as String? ?? 'Voyageur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${flight?['flight_number'] ?? ''} · siège ${pass['seat'] ?? '--'}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanMode() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: _scannerController, onDetect: _onDetect),
              if (_locked)
                Container(color: Colors.black.withValues(alpha: 0.35)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _processing
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildOutcome(
                        icon: Icons.error_outline,
                        color: Colors.redAccent,
                        message: _error!,
                      )
                    : _result == null
                        ? const Center(child: Text('Scannez un QR code de carte d\'embarquement', style: TextStyle(color: AppColors.inkSoft)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: SingleChildScrollView(child: _ResultCard(data: _result!))),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _scanNext,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scanner suivant'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ],
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutcome({required IconData icon, required Color color, required String message}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: color)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _scanNext,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner suivant'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ],
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

    return Container(
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
    );
  }
}
