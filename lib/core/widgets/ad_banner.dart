import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  final _pageController = PageController();
  Timer? _rotationTimer;
  int _index = 0;
  int _lastCount = -1;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _ads = [];
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    SupabaseService.getActiveAdsOnce().then((ads) {
      if (!mounted) return;
      setState(() {
        _ads = ads;
        _loadedOnce = true;
      });
      _startRotation();
    });

    _sub = SupabaseService.watchActiveAds().listen((ads) {
      if (!mounted) return;
      setState(() {
        _ads = ads;
        _loadedOnce = true;
      });
      _startRotation();
    });
  }

  void _startRotation() {
    // On ne touche au minuteur QUE si on va vraiment le recréer —
    // ne jamais annuler un minuteur en cours sans le remplacer.
    if (_ads.length == _lastCount || _ads.length <= 1) {
      _lastCount = _ads.length;
      return;
    }
    _lastCount = _ads.length;
    _rotationTimer?.cancel();
    _index = 0;
    _rotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients || _ads.isEmpty) return;
      _index = (_index + 1) % _ads.length;
      _pageController.animateToPage(_index, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _sub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      return const SizedBox(height: 84);
    }
    if (_ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 84,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _ads.length,
          itemBuilder: (context, i) {
            final ad = _ads[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  ad['image_url'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : Container(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 10,
                  right: 14,
                  child: Text(
                    ad['title'] as String,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
