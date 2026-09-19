import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/crown_theme.dart';
import '../../game_engine/checkers_engine.dart';
import '../../persistence/crown_repository.dart';
import '../match/checkers_board.dart';
import '../match/jump_animation.dart';
import '../match/player_strip.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({
    required this.record,
    required this.repository,
    super.key,
  });

  final MatchRecord record;
  final CrownRepository repository;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  static const _cadence = Duration(milliseconds: 700);
  static const _movementDuration = Duration(milliseconds: 260);

  late final List<GameState> _states = widget.record.replayStates();
  late final List<Turn> _turns = widget.record.finalState.turns;
  CrownSettings _settings = const CrownSettings();
  Map<Square, Piece>? _displayPieces;
  JumpAnimation? _activeMove;
  Timer? _playTimer;
  int _index = 0;
  int _playGeneration = 0;
  int _transitionGeneration = 0;
  bool _isPlaying = false;
  bool _isTransitioning = false;
  bool _resumeAfterScrub = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.repository.loadSettings();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    _playGeneration++;
    _transitionGeneration++;
    _playTimer?.cancel();
    super.dispose();
  }

  bool get _atEnd => _index == _turns.length;
  bool get _reducedMotion =>
      _settings.reducedMotion || MediaQuery.disableAnimationsOf(context);

  void _pause() {
    _playGeneration++;
    _playTimer?.cancel();
    _playTimer = null;
    if (_isPlaying && mounted) setState(() => _isPlaying = false);
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pause();
      return;
    }
    if (_turns.isEmpty || _isTransitioning) return;
    if (_atEnd) {
      setState(() {
        _index = 0;
        _displayPieces = null;
        _activeMove = null;
      });
    }
    final generation = ++_playGeneration;
    setState(() => _isPlaying = true);
    _runAutoplayMove(generation);
  }

  Future<void> _runAutoplayMove(int generation) async {
    if (!mounted || !_isPlaying || generation != _playGeneration || _atEnd) {
      return;
    }
    final turn = _turns[_index];
    final duration = _reducedMotion
        ? Duration.zero
        : _segmentDuration(turn) * turn.landings.length;
    await _move(forward: true);
    if (!mounted || !_isPlaying || generation != _playGeneration) return;
    if (_atEnd) {
      setState(() => _isPlaying = false);
      return;
    }
    final wait = _cadence - duration;
    _playTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _runAutoplayMove(generation);
    });
  }

  Future<void> _manualMove({required bool forward}) async {
    _pause();
    await _move(forward: forward);
  }

  Future<void> _move({required bool forward}) async {
    if (_isTransitioning || forward && _atEnd || !forward && _index == 0) {
      return;
    }
    final sourceIndex = _index;
    final targetIndex = forward ? _index + 1 : _index - 1;
    final turn = _turns[forward ? _index : _index - 1];
    if (_reducedMotion) {
      setState(() => _index = targetIndex);
      return;
    }

    final transitionGeneration = ++_transitionGeneration;
    final board = Map<Square, Piece>.of(_states[sourceIndex].pieces);
    final movingPiece = board[forward ? turn.origin : turn.destination]!;
    var from = forward ? turn.origin : turn.destination;
    final segmentDuration = _segmentDuration(turn);
    setState(() {
      _isTransitioning = true;
      _displayPieces = board;
    });

    for (var segment = 0; segment < turn.landings.length; segment++) {
      final turnIndex = forward ? segment : turn.landings.length - segment - 1;
      final to = forward
          ? turn.landings[turnIndex]
          : turnIndex == 0
          ? turn.origin
          : turn.landings[turnIndex - 1];
      board.remove(from);
      setState(() {
        _displayPieces = Map<Square, Piece>.of(board);
        _activeMove = JumpAnimation(
          piece: movingPiece,
          from: from,
          to: to,
          captured: turn.isCapture ? turn.captures[turnIndex] : null,
          duration: segmentDuration,
        );
      });
      await Future<void>.delayed(segmentDuration);
      if (!mounted || transitionGeneration != _transitionGeneration) return;

      if (turn.isCapture) {
        final captured = turn.captures[turnIndex];
        if (forward) {
          board.remove(captured);
        } else {
          board[captured] = _states[targetIndex].pieces[captured]!;
        }
      }
      board[to] = movingPiece;
      from = to;
      setState(() {
        _activeMove = null;
        _displayPieces = Map<Square, Piece>.of(board);
      });
    }

    if (!mounted || transitionGeneration != _transitionGeneration) return;
    setState(() {
      _index = targetIndex;
      _displayPieces = null;
      _activeMove = null;
      _isTransitioning = false;
    });
  }

  Duration _segmentDuration(Turn turn) => Duration(
    milliseconds: math.min(
      _movementDuration.inMilliseconds,
      _cadence.inMilliseconds ~/ turn.landings.length,
    ),
  );

  void _jumpTo(int index) {
    _pause();
    if (_isTransitioning) return;
    setState(() {
      _index = index;
      _displayPieces = null;
      _activeMove = null;
    });
  }

  void _beginScrub(double _) {
    _resumeAfterScrub = _isPlaying;
    _pause();
    _transitionGeneration++;
    if (_isTransitioning || _displayPieces != null || _activeMove != null) {
      setState(() {
        _isTransitioning = false;
        _displayPieces = null;
        _activeMove = null;
      });
    }
  }

  void _scrubTo(double value) {
    final index = value.round().clamp(0, _turns.length);
    if (index == _index && _displayPieces == null && _activeMove == null) {
      return;
    }
    setState(() {
      _index = index;
      _displayPieces = null;
      _activeMove = null;
    });
  }

  void _endScrub(double value) {
    _scrubTo(value);
    final resume = _resumeAfterScrub;
    _resumeAfterScrub = false;
    if (resume && !_atEnd) _togglePlayback();
  }

  String _timelineLabel(double value) {
    final index = value.round().clamp(0, _turns.length);
    if (index == 0) return 'Opening position';
    if (index == _turns.length) {
      return 'Final position, move $index of ${_turns.length}';
    }
    return 'Move $index of ${_turns.length}';
  }

  @override
  Widget build(BuildContext context) {
    final stableState = _states[_index];
    final pieces = _displayPieces ?? stableState.pieces;
    final bottomSide = widget.record.bottomSide;
    final topSide = bottomSide.opponent;
    final finalPosition = _atEnd && !_isTransitioning;
    return Scaffold(
      appBar: AppBar(title: const Text('Replay')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 590),
              child: Column(
                children: [
                  PlayerStrip(
                    name: widget.record.nameForSide(topSide),
                    side: topSide,
                    isCrownAi: widget.record.aiSide == topSide,
                    active: !finalPosition && stableState.sideToMove == topSide,
                    pieces: pieces.values
                        .where((piece) => piece.side == topSide)
                        .length,
                  ),
                  const SizedBox(height: 12),
                  CheckersBoard(
                    pieces: pieces,
                    selected: null,
                    destinations: const {},
                    bottomSide: bottomSide,
                    ownerFacingCrowns: widget.record.mode == MatchMode.local,
                    showCoordinates: _settings.showCoordinates,
                    highContrast: _settings.highContrast,
                    reducedMotion: _reducedMotion,
                    lastTurn: _index == 0 ? null : _turns[_index - 1],
                    activeJump: _activeMove,
                  ),
                  const SizedBox(height: 12),
                  PlayerStrip(
                    name: widget.record.nameForSide(bottomSide),
                    side: bottomSide,
                    isCrownAi: widget.record.aiSide == bottomSide,
                    active:
                        !finalPosition && stableState.sideToMove == bottomSide,
                    pieces: pieces.values
                        .where((piece) => piece.side == bottomSide)
                        .length,
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: CrownColors.gold,
                            inactiveTrackColor: CrownColors.ink.withValues(
                              alpha: .12,
                            ),
                            thumbColor: CrownColors.gold,
                            overlayColor: CrownColors.gold.withValues(
                              alpha: .14,
                            ),
                            valueIndicatorColor: CrownColors.obsidian,
                            valueIndicatorTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            showValueIndicator:
                                ShowValueIndicator.onlyForDiscrete,
                          ),
                          child: Slider(
                            key: const ValueKey('replay-timeline'),
                            value: _index.toDouble(),
                            max: _turns.isEmpty ? 1 : _turns.length.toDouble(),
                            divisions: _turns.isEmpty ? null : _turns.length,
                            label: _timelineLabel(_index.toDouble()),
                            semanticFormatterCallback: _timelineLabel,
                            onChangeStart: _turns.isEmpty ? null : _beginScrub,
                            onChanged: _turns.isEmpty ? null : _scrubTo,
                            onChangeEnd: _turns.isEmpty ? null : _endScrub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'First',
                              onPressed: _index == 0 || _isTransitioning
                                  ? null
                                  : () => _jumpTo(0),
                              icon: const Icon(Icons.first_page_rounded),
                            ),
                            IconButton(
                              tooltip: 'Previous',
                              onPressed: _index == 0 || _isTransitioning
                                  ? null
                                  : () => _manualMove(forward: false),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: _isPlaying ? 'Pause' : 'Play',
                              onPressed:
                                  _turns.isEmpty ||
                                      _isTransitioning && !_isPlaying
                                  ? null
                                  : _togglePlayback,
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              onPressed: _atEnd || _isTransitioning
                                  ? null
                                  : () => _manualMove(forward: true),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                            IconButton(
                              tooltip: 'Last',
                              onPressed: _atEnd || _isTransitioning
                                  ? null
                                  : () => _jumpTo(_turns.length),
                              icon: const Icon(Icons.last_page_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
