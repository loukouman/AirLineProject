import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  final String flightId;
  final String flightLabel;

  const TrackingScreen({
    super.key,
    required this.flightId,
    required this.flightLabel,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getJourneyEvents(widget.flightId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SupabaseService.getJourneyEvents(widget.flightId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Suivi · ${widget.flightLabel}')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data ?? [];

            if (events.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(height: 80),
                        Icon(Icons.timeline, size: 56, color: AppColors.inkSoft),
                        SizedBox(height: 16),
                        Text(
                          'Aucun événement enregistré pour ce vol pour le moment',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final now = DateTime.now();
            var nowIndex = events.indexWhere(
              (e) => DateTime.parse(e['event_time'] as String).isAfter(now),
            );
            if (nowIndex == -1) nowIndex = events.length;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i];
                final status = i < nowIndex
                    ? _EventStatus.done
                    : i == nowIndex
                        ? _EventStatus.now
                        : _EventStatus.future;

                return _TimelineTile(
                  title: event['title'] as String,
                  description: event['description'] as String?,
                  time: DateTime.parse(event['event_time'] as String),
                  status: status,
                  isLast: i == events.length - 1,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _EventStatus { done, now, future }

class _TimelineTile extends StatelessWidget {
  final String title;
  final String? description;
  final DateTime time;
  final _EventStatus status;
  final bool isLast;

  const _TimelineTile({
    required this.title,
    this.description,
    required this.time,
    required this.status,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (status) {
      _EventStatus.done => AppColors.success,
      _EventStatus.now => AppColors.coral,
      _EventStatus.future => AppColors.inkSoft.withValues(alpha: 0.4),
    };
    final titleColor = status == _EventStatus.now ? AppColors.coral : AppColors.ink;
    final timeLabel = status == _EventStatus.now ? 'Maintenant' : DateFormat('HH:mm').format(time);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: status == _EventStatus.now
                      ? [BoxShadow(color: AppColors.coral.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 3)]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: Colors.black.withValues(alpha: 0.08)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(description!, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
