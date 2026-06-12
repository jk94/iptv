import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Fullscreen live-stream player with auto-hiding controls.
class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  /// Opens the player and records the stream as recently watched.
  static void open(
    BuildContext context, {
    required Channel channel,
    required String playlistName,
  }) {
    context.read<AppState>().addRecent(channel, playlistName);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) {
        setState(() {});
        _scheduleHide();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Stream konnte nicht geladen werden.\nBitte Quelle prüfen.');
      }
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null)
              _PlayerError(message: _error!, channelName: widget.channel.name)
            else if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_controlsVisible || _error != null)
              _ControlsOverlay(
                channelName: widget.channel.name,
                controller: ready ? controller : null,
                onInteraction: _scheduleHide,
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final String channelName;
  final VideoPlayerController? controller;
  final VoidCallback onInteraction;

  const _ControlsOverlay({
    required this.channelName,
    required this.controller,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black54],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const _LiveBadge(),
                const SizedBox(width: 16),
              ],
            ),
            const Spacer(),
            if (controller != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller!,
                builder: (context, value, _) => IconButton(
                  iconSize: 72,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    value.isPlaying ? controller!.pause() : controller!.play();
                    onInteraction();
                  },
                ),
              ),
            const Spacer(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  final String message;
  final String channelName;
  const _PlayerError({required this.message, required this.channelName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            channelName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
