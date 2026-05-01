import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';

/// Screen 4: Video Player
/// Full-screen video player with brutalist overlay controls.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoName;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoName,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _controlsVisible = true;
  bool _isBuffering = true;

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

    // Listen for buffering state
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    // Open the video
    _player.open(Media(widget.videoUrl));
  }

  @override
  void dispose() {
    _player.dispose();

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

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

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
    return Scaffold(
      backgroundColor: BrutalistTheme.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
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

            // ─── BUFFERING INDICATOR ───────
            if (_isBuffering)
              const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: BrutalistTheme.accent,
                  ),
                ),
              ),

            // ─── CONTROLS OVERLAY ──────────
            if (_controlsVisible) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
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
                    border: Border.all(
                        color: BrutalistTheme.white, width: 2),
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
              // Seek bar
              StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, posSnap) {
                  return StreamBuilder<Duration>(
                    stream: _player.stream.duration,
                    builder: (context, durSnap) {
                      final position =
                          posSnap.data ?? Duration.zero;
                      final duration =
                          durSnap.data ?? Duration.zero;
                      final maxVal = duration.inMilliseconds
                          .toDouble()
                          .clamp(1.0, double.infinity);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 6,
                              thumbShape:
                                  const RectangularSliderThumbShape(),
                              activeTrackColor:
                                  BrutalistTheme.accent,
                              inactiveTrackColor: BrutalistTheme
                                  .white
                                  .withValues(alpha: 0.3),
                              thumbColor: BrutalistTheme.white,
                              overlayColor: BrutalistTheme.accent
                                  .withValues(alpha: 0.3),
                              trackShape:
                                  const RectangularSliderTrackShape(),
                            ),
                            child: Slider(
                              value: position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, maxVal),
                              max: maxVal,
                              onChanged: (v) {
                                _player.seek(Duration(
                                    milliseconds: v.toInt()));
                              },
                            ),
                          ),

                          // Time display
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: BrutalistTheme.mono
                                      .copyWith(
                                    color: BrutalistTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: BrutalistTheme.mono
                                      .copyWith(
                                    color: BrutalistTheme.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 8),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  _ControlButton(
                    icon: Icons.replay_10,
                    onTap: () async {
                      final pos = await _player.stream.position.first;
                      _player.seek(
                          pos - const Duration(seconds: 10));
                    },
                  ),

                  const SizedBox(width: 20),

                  // Play/Pause
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (context, snap) {
                      final isPlaying = snap.data ?? false;
                      return _ControlButton(
                        icon: isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        large: true,
                        onTap: () => _player.playOrPause(),
                      );
                    },
                  ),

                  const SizedBox(width: 20),

                  // Forward 10s
                  _ControlButton(
                    icon: Icons.forward_10,
                    onTap: () async {
                      final pos = await _player.stream.position.first;
                      _player.seek(
                          pos + const Duration(seconds: 10));
                    },
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
  final VoidCallback onTap;
  final bool large;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: large ? 64 : 48,
        height: large ? 64 : 48,
        decoration: BoxDecoration(
          color: large
              ? BrutalistTheme.accent
              : BrutalistTheme.black.withValues(alpha: 0.5),
          border: Border.all(color: BrutalistTheme.white, width: 2),
        ),
        child: Icon(
          icon,
          color: BrutalistTheme.white,
          size: large ? 36 : 24,
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
