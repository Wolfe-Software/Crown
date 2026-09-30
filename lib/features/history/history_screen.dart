import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../app/crown_wordmark.dart';
import '../../persistence/crown_repository.dart';
import 'match_record_row.dart';
import 'replay_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.repository,
    this.active = true,
    this.bottomPadding = 24,
    super.key,
  });
  final CrownRepository repository;
  final bool active;
  final double bottomPadding;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FeedEntry> _entries = const [];
  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    final value = await widget.repository.loadFeed();
    if (mounted) setState(() => _entries = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('feed-scroll'),
        slivers: [
          SliverAppBar(floating: true, backgroundColor: Colors.transparent),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverToBoxAdapter(
              child: CrownWordmark(
                title: 'FEED',
                logo: Image.asset(
                  'assets/FeedLogo.png',
                  key: const ValueKey('feed-header-logo'),
                  width: 42,
                  height: 42,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 34)),
          if (_entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(32, 0, 32, widget.bottomPadding),
                child: const Center(
                  child: GlassPanel(
                    child: Text(
                      'Matches, lessons, and challenges will appear here.',
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, widget.bottomPadding),
              sliver: SliverList.separated(
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return FeedEntryRow(
                    entry: _entries[index],
                    onReplay: (record) => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ReplayScreen(
                          record: record,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
