import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/supabase_service.dart';
import '../services/data_saver_service.dart';
import '../theme/app_theme.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static const _imageDuration = Duration(seconds: 5);
  static const _bannerHeight = 160.0;

  final _pageController = PageController();
  final _videoKeys = <String, GlobalKey<_AdVideoGroupState>>{};
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
      _resetRotation();
    });

    _sub = SupabaseService.watchActiveAds().listen((ads) {
      if (!mounted) return;
      setState(() {
        _ads = ads;
        _loadedOnce = true;
      });
      _resetRotation();
    });
  }

  void _resetRotation() {
    if (_ads.length == _lastCount || _ads.length <= 1) {
      _lastCount = _ads.length;
      return;
    }
    _lastCount = _ads.length;
    _index = 0;
    _scheduleForCurrent();
  }

  void _scheduleForCurrent() {
    _rotationTimer?.cancel();
    if (_ads.isEmpty || _ads.length <= 1) return;

    final type = _ads[_index]['media_type'] as String? ?? 'image';
    if (type != 'video') {
      _rotationTimer = Timer(_imageDuration, _advance);
    }
  }

  void _advance() {
    if (!mounted || !_pageController.hasClients || _ads.isEmpty) return;
    final next = (_index + 1) % _ads.length;
    _pageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _sub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<String> _urlsFor(Map<String, dynamic> ad) {
    final list = ad['media_urls'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => e as String).toList();
    }
    return [ad['image_url'] as String];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      return const SizedBox(height: _bannerHeight);
    }
    if (_ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _bannerHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _ads.length,
          onPageChanged: (i) {
            _index = i;
            _scheduleForCurrent();
          },
          itemBuilder: (context, i) {
            final ad = _ads[i];
            final mediaType = ad['media_type'] as String? ?? 'image';
            final adId = ad['id'] as String;
            if (mediaType == 'video') {
              _videoKeys.putIfAbsent(adId, () => GlobalKey<_AdVideoGroupState>());
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                if (mediaType == 'video')
                  _AdVideoGroup(
                    key: _videoKeys[adId],
                    urls: _urlsFor(ad),
                    onFinished: () {
                      if (_index == i) _advance();
                    },
                  )
                else
                  Image.network(
                    ad['image_url'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : Container(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 10,
                  right: 14,
                  child: IgnorePointer(
                    child: Text(
                      ad['title'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Zone de tap AU NIVEAU LE PLUS HAUT de toute la cellule,
                // en comportement opaque : garantit de capter le tap avant
                // toute subtilité interne du widget vidéo (texture/surface).
                if (mediaType == 'video')
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('AdBanner: tap détecté sur la pub vidéo $adId');
                        _videoKeys[adId]?.currentState?.toggleMute();
                      },
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

/// Joue une suite de vidéos bout à bout via media_kit (décodage logiciel,
/// indépendant du décodeur matériel Android — évite les plantages sur les
/// puces d'entrée de gamme dont le MediaCodec est bugué).
class _AdVideoGroup extends StatefulWidget {
  final List<String> urls;
  final VoidCallback onFinished;
  const _AdVideoGroup({super.key, required this.urls, required this.onFinished});

  @override
  State<_AdVideoGroup> createState() => _AdVideoGroupState();
}

class _AdVideoGroupState extends State<_AdVideoGroup> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  int _segmentIndex = 0;
  bool _muted = true;
  bool _failed = false;
  bool _finishedSignaled = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _errorSub = _player.stream.error.listen((error) {
      debugPrint('AdBanner (media_kit): échec de lecture vidéo (${widget.urls[_segmentIndex]}) → $error');
      if (mounted) setState(() => _failed = true);
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) _goToNextSegmentOrFinish();
    });

    // En mode économe en données, la vidéo ne se lance pas automatiquement :
    // le voyageur doit taper une première fois pour la charger et la voir.
    if (!DataSaverService.effective.value) {
      _started = true;
      _playSegment(0);
    }
  }

  Future<void> _playSegment(int index) async {
    setState(() {
      _segmentIndex = index;
      _failed = false;
    });
    await _player.open(Media(widget.urls[index]), play: true);
    await _player.setVolume(_muted ? 0 : 100);

    await Future.delayed(const Duration(milliseconds: 800));
    final nbAudio = _player.state.tracks.audio.length;
    final currentVolume = _player.state.volume;
    debugPrint('AdBanner (media_kit): pistes audio disponibles = $nbAudio');
    debugPrint('AdBanner (media_kit): volume actuel = $currentVolume');
    if (nbAudio == 0) {
      debugPrint('AdBanner (media_kit): ATTENTION cette video ne contient AUCUNE piste audio (fichier source muet).');
    }
  }

  void _goToNextSegmentOrFinish() {
    if (_finishedSignaled) return;
    final next = _segmentIndex + 1;
    if (next < widget.urls.length) {
      _playSegment(next);
    } else {
      _finishedSignaled = true;
      widget.onFinished();
    }
  }

  /// Appelé depuis l'extérieur (AdBanner) via GlobalKey, puisque le geste
  /// de tap est désormais capté au niveau de la cellule entière plutôt
  /// qu'à l'intérieur de ce widget. Premier tap : démarre la vidéo (utile
  /// en mode économe en données, où elle n'est pas chargée automatiquement).
  /// Taps suivants : active/coupe le son.
  void toggleMute() {
    if (!_started) {
      setState(() => _started = true);
      _playSegment(_segmentIndex);
      return;
    }
    final newMuted = !_muted;
    debugPrint('AdBanner (media_kit): toggleMute appele, _muted passe de $_muted a $newMuted');
    setState(() {
      _muted = newMuted;
      _player.setVolume(_muted ? 0 : 100);
    });
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: AppColors.primary.withValues(alpha: 0.25),
        child: const Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 28),
        ),
      );
    }

    if (!_started) {
      return Container(
        color: AppColors.primary.withValues(alpha: 0.35),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
              SizedBox(height: 6),
              Text(
                'Toucher pour charger la vidéo\n(mode économe en données)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10.5),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Video(controller: _controller, fit: BoxFit.cover, controls: NoVideoControls),
        if (widget.urls.length > 1)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              children: List.generate(widget.urls.length, (i) {
                final done = i < _segmentIndex;
                final current = i == _segmentIndex;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 3,
                    decoration: BoxDecoration(
                      color: done || current ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        Positioned(
          right: 8,
          top: widget.urls.length > 1 ? 16 : 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
            child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }
}
