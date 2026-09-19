import 'dart:async';
import 'package:flutter/material.dart';

/// Affiche un compte à rebours en temps réel jusqu'à [target].
/// Se met à jour chaque seconde. Affiche [pastLabel] une fois la cible dépassée.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final String Function(Duration remaining)? formatter;
  final String pastLabel;

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.formatter,
    this.pastLabel = 'En cours',
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.target.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.target.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _defaultFormat(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return 'Départ dans ${h}h ${m.toString().padLeft(2, '0')}min';
    return 'Départ dans ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return Text(widget.pastLabel, style: widget.style);
    }
    final label = widget.formatter != null ? widget.formatter!(_remaining) : _defaultFormat(_remaining);
    return Text(label, style: widget.style);
  }
}
