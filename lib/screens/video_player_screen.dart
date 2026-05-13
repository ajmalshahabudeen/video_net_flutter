import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';

/// Screen 4: Video Player
/// Full-screen video player with brutalist overlay controls.
/// Supports double-tap skip, volume/brightness gestures, and next/previous.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoName;

  /// Callback to play the next video. Null if no next video available.
  final VoidCallback? onNextVideo;

  /// Callback to play the previous video. Null if no previous video available.
  final VoidCallback? onPreviousVideo;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoName,
    this.onNextVideo,
    this.onPreviousVideo,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;
  bool _controlsVisible = true;
  bool _isBuffering = true;

  // ─── Cached position/duration to persist across controls toggle ───
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  // ─── Stream subscriptions ─────────────────────────────────────────
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _playingSub;

  // ─── Auto-hide timer ──────────────────────────────────────────────
  Timer? _hideTimer;

  // ─── Double-tap skip feedback ─────────────────────────────────────
  _SkipDirection? _skipDirection;
  int _skipSeconds = 0;
  Timer? _skipResetTimer;
  late AnimationController _skipAnimController;
  late Animation<double> _skipFadeAnim;

  // ─── Volume / Brightness gesture ──────────────────────────────────
  bool _isDraggingVolume = false;
  bool _isDraggingBrightness = false;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  late AnimationController _volumeAnimController;
  late AnimationController _brightnessAnimController;
  Timer? _volumeHideTimer;
  Timer? _brightnessHideTimer;

  // ─── Auto-fix stall detection ─────────────────────────────────────
  Timer? _stallTimer;
  Duration _lastKnownPosition = Duration.zero;
  bool _isAutoFixing = false;
  int _autoFixAttempts = 0;
  // ignore: unused_field
  static const int _stallTimeoutSecs = 15;
  static const int _maxAutoFixAttempts = 2;

  @override
  void initState() {
    super.initState();

    // Set landscape orientation for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _controller = VideoController(_player);

    // Animation controllers
    _skipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _skipFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _skipAnimController, curve: Curves.easeOut),
    );

    _volumeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _brightnessAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for buffering state
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    // Cache position persistently
    _positionSub = _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    // Cache duration persistently
    _durationSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    // Cache playing state
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    // Initialize volume
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((vol) {
      if (mounted) setState(() => _currentVolume = vol);
    });

    // Initialize brightness
    ScreenBrightness.instance.application.then((brightness) {
      if (mounted) setState(() => _currentBrightness = brightness);
    });

    // Open the video
    _player.open(Media(widget.videoUrl));

    // Start auto-hide timer
    _startHideTimer();

    // Start stall detection
    _startStallDetection();
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _playingSub?.cancel();
    _hideTimer?.cancel();
    _skipResetTimer?.cancel();
    _volumeHideTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _skipAnimController.dispose();
    _volumeAnimController.dispose();
    _brightnessAnimController.dispose();
    _player.dispose();

    // Reset brightness
    ScreenBrightness.instance.resetApplicationScreenBrightness();

    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Stop proxy
    final state = context.read<AppState>();
    state.stopVideo();

    super.dispose();
  }

  // ─── Controls Visibility ──────────────────────────────────────────

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  // ─── Stall Detection & Auto-Fix ───────────────────────────────────

  void _startStallDetection() {
    _stallTimer?.cancel();
    _stallTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkForStall(),
    );
  }

  void _checkForStall() {
    if (_isAutoFixing || !mounted) return;
    if (_autoFixAttempts >= _maxAutoFixAttempts) return;

    // Only check if we're supposed to be playing but stuck buffering
    final isStuck = _isBuffering &&
        _position == _lastKnownPosition &&
        _position == Duration.zero &&
        _duration == Duration.zero;

    if (isStuck) {
      // Check how long we've been in this state — use a simple counter
      _autoFixAttempts++;
      _performAutoFix();
    } else {
      _lastKnownPosition = _position;
    }
  }

  Future<void> _performAutoFix() async {
    if (!mounted) return;
    setState(() => _isAutoFixing = true);

    try {
      final state = context.read<AppState>();

      // Save the file path before stopping (stopProxy clears it)
      final savedFilePath = state.proxyService.filePath;
      if (savedFilePath == null || savedFilePath.isEmpty) return;

      // Step 1: Clear the chunk cache to remove any corrupted data
      final cache = state.proxyService.cache;
      if (cache != null) {
        await cache.clearAndReset();
      }

      // Step 2: Stop and restart the proxy
      await state.proxyService.stopProxy();

      // Brief pause to let resources clean up
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Restart proxy with same file
      final url = await state.proxyService.startProxy(
        smbService: state.smbService,
        filePath: savedFilePath,
      );

      if (!mounted) return;

      // Step 4: Reload the video with the new URL
      await _player.stop();
      await _player.open(Media(url));
    } catch (e) {
      // If auto-fix fails, just continue — user can manually retry
    } finally {
      if (mounted) {
        setState(() => _isAutoFixing = false);
      }
    }
  }

  // ─── Double-Tap Skip ──────────────────────────────────────────────

  void _handleDoubleTap(_SkipDirection direction) {
    final skipAmount = const Duration(seconds: 10);

    if (_skipDirection == direction) {
      _skipSeconds += 10;
    } else {
      _skipSeconds = 10;
      _skipDirection = direction;
    }

    if (direction == _SkipDirection.forward) {
      _player.seek(_position + skipAmount);
    } else {
      _player.seek(
        Duration(milliseconds: max(0, (_position - skipAmount).inMilliseconds)),
      );
    }

    _skipAnimController.forward(from: 0);
    _skipResetTimer?.cancel();
    _skipResetTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _skipDirection = null;
          _skipSeconds = 0;
        });
      }
    });

    setState(() {});
  }

  // ─── Volume / Brightness Gestures ─────────────────────────────────

  void _onVerticalDragStart(DragStartDetails details, bool isRight) {
    if (isRight) {
      _isDraggingVolume = true;
      _volumeAnimController.forward();
    } else {
      _isDraggingBrightness = true;
      _brightnessAnimController.forward();
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, bool isRight) {
    // Negative dy = drag up = increase value
    final delta = -(details.primaryDelta ?? 0) / 300;

    if (isRight && _isDraggingVolume) {
      _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
      VolumeController.instance.setVolume(_currentVolume);
    } else if (!isRight && _isDraggingBrightness) {
      _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
      ScreenBrightness.instance
          .setApplicationScreenBrightness(_currentBrightness);
    }
    setState(() {});
  }

  void _onVerticalDragEnd(bool isRight) {
    if (isRight) {
      _isDraggingVolume = false;
      _volumeHideTimer?.cancel();
      _volumeHideTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _volumeAnimController.reverse();
      });
    } else {
      _isDraggingBrightness = false;
      _brightnessHideTimer?.cancel();
      _brightnessHideTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _brightnessAnimController.reverse();
      });
    }
    setState(() {});
  }

  // ─── Formatting ───────────────────────────────────────────────────

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: BrutalistTheme.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── VIDEO ─────────────────────
          Center(
            child: Video(
              controller: _controller,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
          ),

          // ─── GESTURE ZONES ─────────────
          Row(
            children: [
              // Left zone — brightness + double-tap rewind
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: () =>
                      _handleDoubleTap(_SkipDirection.backward),
                  onVerticalDragStart: (d) =>
                      _onVerticalDragStart(d, false),
                  onVerticalDragUpdate: (d) =>
                      _onVerticalDragUpdate(d, false),
                  onVerticalDragEnd: (_) => _onVerticalDragEnd(false),
                  child: const SizedBox.expand(),
                ),
              ),
              // Center zone — just toggle controls
              SizedBox(
                width: screenWidth * 0.2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  child: const SizedBox.expand(),
                ),
              ),
              // Right zone — volume + double-tap forward
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: () =>
                      _handleDoubleTap(_SkipDirection.forward),
                  onVerticalDragStart: (d) =>
                      _onVerticalDragStart(d, true),
                  onVerticalDragUpdate: (d) =>
                      _onVerticalDragUpdate(d, true),
                  onVerticalDragEnd: (_) => _onVerticalDragEnd(true),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),

          // ─── BUFFERING INDICATOR ───────
          if (_isBuffering)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: BrutalistTheme.accent,
                    ),
                  ),
                  if (_isAutoFixing) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: BrutalistTheme.black.withValues(alpha: 0.85),
                        border: Border.all(
                            color: BrutalistTheme.warning, width: 2),
                      ),
                      child: Text(
                        'AUTO-FIXING: CLEARING CACHE...',
                        style: BrutalistTheme.mono.copyWith(
                          color: BrutalistTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ─── SKIP FEEDBACK OVERLAY ─────
          if (_skipDirection != null)
            _buildSkipFeedback(),

          // ─── VOLUME INDICATOR ──────────
          _buildVerticalIndicator(
            controller: _volumeAnimController,
            value: _currentVolume,
            icon: _currentVolume <= 0
                ? Icons.volume_off
                : _currentVolume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
            alignment: Alignment.centerRight,
          ),

          // ─── BRIGHTNESS INDICATOR ──────
          _buildVerticalIndicator(
            controller: _brightnessAnimController,
            value: _currentBrightness,
            icon: _currentBrightness <= 0.3
                ? Icons.brightness_low
                : _currentBrightness < 0.7
                    ? Icons.brightness_medium
                    : Icons.brightness_high,
            alignment: Alignment.centerLeft,
          ),

          // ─── CONTROLS OVERLAY ──────────
          if (_controlsVisible) _buildControls(),
        ],
      ),
    );
  }

  // ─── Skip Feedback Widget ─────────────────────────────────────────

  Widget _buildSkipFeedback() {
    final isForward = _skipDirection == _SkipDirection.forward;

    return AnimatedBuilder(
      animation: _skipFadeAnim,
      builder: (context, child) {
        return Positioned(
          left: isForward ? null : 40,
          right: isForward ? 40 : null,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: _skipFadeAnim.value,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: BrutalistTheme.black.withValues(alpha: 0.7),
                  border: Border.all(color: BrutalistTheme.accent, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward ? Icons.forward_10 : Icons.replay_10,
                      color: BrutalistTheme.accent,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_skipSeconds}s',
                      style: BrutalistTheme.mono.copyWith(
                        color: BrutalistTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Vertical Indicator (Volume / Brightness) ────────────────────

  Widget _buildVerticalIndicator({
    required AnimationController controller,
    required double value,
    required IconData icon,
    required Alignment alignment,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.value == 0) return const SizedBox.shrink();

        return Align(
          alignment: alignment,
          child: Opacity(
            opacity: controller.value,
            child: Container(
              margin: EdgeInsets.only(
                left: alignment == Alignment.centerLeft ? 24 : 0,
                right: alignment == Alignment.centerRight ? 24 : 0,
              ),
              width: 42,
              height: 180,
              decoration: BoxDecoration(
                color: BrutalistTheme.black.withValues(alpha: 0.85),
                border: Border.all(color: BrutalistTheme.white, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: BrutalistTheme.accent, size: 22),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor:
                              BrutalistTheme.white.withValues(alpha: 0.2),
                          color: BrutalistTheme.accent,
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(value * 100).toInt()}',
                    style: BrutalistTheme.mono.copyWith(
                      color: BrutalistTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Controls Overlay ─────────────────────────────────────────────

  Widget _buildControls() {
    final maxVal =
        _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);

    return Column(
      children: [
        // ─── TOP BAR ─────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            8,
            MediaQuery.of(context).padding.top + 8,
            8,
            8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BrutalistTheme.black.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: BrutalistTheme.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: BrutalistTheme.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.videoName,
                  style: BrutalistTheme.mono.copyWith(
                    color: BrutalistTheme.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ─── BOTTOM CONTROLS ─────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                BrutalistTheme.black.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            children: [
              // Seek bar — uses cached state, NOT streams
              Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      thumbShape: const RectangularSliderThumbShape(),
                      activeTrackColor: BrutalistTheme.accent,
                      inactiveTrackColor:
                          BrutalistTheme.white.withValues(alpha: 0.3),
                      thumbColor: BrutalistTheme.white,
                      overlayColor:
                          BrutalistTheme.accent.withValues(alpha: 0.3),
                      trackShape: const RectangularSliderTrackShape(),
                    ),
                    child: Slider(
                      value: _position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, maxVal),
                      max: maxVal,
                      onChanged: (v) {
                        _player
                            .seek(Duration(milliseconds: v.toInt()));
                      },
                      onChangeStart: (_) {
                        _hideTimer?.cancel();
                      },
                      onChangeEnd: (_) {
                        _startHideTimer();
                      },
                    ),
                  ),

                  // Time display — uses cached state
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: BrutalistTheme.mono.copyWith(
                            color: BrutalistTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: BrutalistTheme.mono.copyWith(
                            color: BrutalistTheme.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous video
                  _ControlButton(
                    icon: Icons.skip_previous,
                    onTap: widget.onPreviousVideo,
                    disabled: widget.onPreviousVideo == null,
                  ),

                  const SizedBox(width: 12),

                  // Rewind 10s
                  _ControlButton(
                    icon: Icons.replay_10,
                    onTap: () {
                      _player.seek(Duration(
                        milliseconds: max(
                            0,
                            (_position - const Duration(seconds: 10))
                                .inMilliseconds),
                      ));
                    },
                  ),

                  const SizedBox(width: 12),

                  // Play/Pause — uses cached state
                  _ControlButton(
                    icon:
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                    large: true,
                    onTap: () => _player.playOrPause(),
                  ),

                  const SizedBox(width: 12),

                  // Forward 10s
                  _ControlButton(
                    icon: Icons.forward_10,
                    onTap: () {
                      _player.seek(
                          _position + const Duration(seconds: 10));
                    },
                  ),

                  const SizedBox(width: 12),

                  // Next video
                  _ControlButton(
                    icon: Icons.skip_next,
                    onTap: widget.onNextVideo,
                    disabled: widget.onNextVideo == null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Brutalist control button for the video player.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool large;
  final bool disabled;

  const _ControlButton({
    required this.icon,
    this.onTap,
    this.large = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.3 : 1.0,
        child: Container(
          width: large ? 64 : 44,
          height: large ? 64 : 44,
          decoration: BoxDecoration(
            color: large
                ? BrutalistTheme.accent
                : BrutalistTheme.black.withValues(alpha: 0.5),
            border: Border.all(color: BrutalistTheme.white, width: 2),
          ),
          child: Icon(
            icon,
            color: BrutalistTheme.white,
            size: large ? 36 : 22,
          ),
        ),
      ),
    );
  }
}

/// Rectangular slider thumb for brutalist aesthetics.
class RectangularSliderThumbShape extends SliderComponentShape {
  const RectangularSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(14, 20);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? BrutalistTheme.white
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: center,
      width: 14,
      height: 20,
    );

    canvas.drawRect(rect, paint);

    // Border
    final borderPaint = Paint()
      ..color = BrutalistTheme.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(rect, borderPaint);
  }
}

enum _SkipDirection { forward, backward }
