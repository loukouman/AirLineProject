import 'package:flutter/material.dart';

/// Rectangle animé en "pulsation" utilisé comme espace réservé
/// pendant le chargement d'un contenu, au lieu d'un simple spinner.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 12,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            height: widget.height,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E4DF),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// Squelette utilisé pendant le chargement d'une carte de vol
/// ou d'une carte d'embarquement, à la place d'un spinner centré.
class FlightCardSkeleton extends StatelessWidget {
  const FlightCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(height: 150, borderRadius: 22),
        SizedBox(height: 20),
        SkeletonBox(height: 14, width: 120, borderRadius: 6),
        SizedBox(height: 10),
        SkeletonBox(height: 60, borderRadius: 14),
        SizedBox(height: 8),
        SkeletonBox(height: 60, borderRadius: 14),
      ],
    );
  }
}


/// Squelette utilisé pendant le chargement d'une timeline de suivi de vol.
class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 12, width: 12, borderRadius: 6),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(height: 10, width: 60, borderRadius: 4),
                      const SizedBox(height: 8),
                      const SkeletonBox(height: 14, width: 140, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
