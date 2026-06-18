import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Fullscreen live-stream player.
///
/// Plays one stream out of [channels] (the streams of the selected category)
/// and lets the user jump to the previous/next stream of that list. On
/// Android the playback continues in a Picture-in-Picture window when the
/// app is sent to the background.
class PlayerScreen extends StatefulWidget {
  /// The streams of the selected category, used for prev/next navigation.
  final List<Channel> channels;
  final int initialIndex;
  final String playlistName;

  const PlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
    required this.playlistName,
  });

  static void open(
    BuildContext context, {
    required List<Channel> channels,
    required int initialIndex,
    required String playlistName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channels: channels,
          initialIndex: initialIndex,
          playlistName: playlistName,
        ),
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final SimplePip _pip = SimplePip();

  VideoPlayerController? _controller;
  Timer? _hideTimer;
  late int _currentIndex;

  // Guards against overlapping channel switches: only the latest load wins.
  int _loadToken = 0;

  bool _controlsVisible = true;
  bool _isInPip = false;
  bool _autoPipAvailable = false;
  String? _error;

  Channel get _channel => widget.channels[_currentIndex];
  bool get _hasMultiple => widget.channels.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _setupPip();
    _loadCurrent();
  }

  Future<void> _setupPip() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await SimplePip.isPipAvailable) return;
      _autoPipAvailable = await SimplePip.isAutoPipAvailable;
      // Android 12+: the system enters PiP automatically on "home".
      if (_autoPipAvailable) {
        await _pip.setAutoPipMode();
      }
    } catch (_) {
      // PiP simply stays unavailable on this device.
    }
  }

  Future<void> _loadCurrent() async {
    final token = ++_loadToken;
    final appState = context.read<AppState>();
    final channel = _channel;
    appState.addRecent(channel, widget.playlistName);

    await _controller?.dispose();
    _controller = null;
    if (mounted && token == _loadToken) setState(() => _error = null);

    final controller =
        VideoPlayerController.networkUrl(Uri.parse(channel.url));
    try {
      await controller.initialize();
      if (token != _loadToken) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.play();
      if (mounted) {
        setState(() {});
        _scheduleHide();
      }
    } catch (_) {
      await controller.dispose();
      if (token == _loadToken && mounted) {
        setState(() => _error =
            'Stream konnte nicht geladen werden.\nBitte Quelle prüfen.');
      }
    }
  }

  void _switchBy(int delta) {
    if (!_hasMultiple) return;
    final count = widget.channels.length;
    setState(() {
      _currentIndex = (_currentIndex + delta) % count;
      if (_currentIndex < 0) _currentIndex += count;
    });
    _loadCurrent();
    _scheduleHide();
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

  Future<void> _enterPip() async {
    if (!Platform.isAndroid) return;
    try {
      await _pip.enterPipMode();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fallback for Android versions without auto-enter (< 12): request PiP
    // when the app is being sent to the background while playing.
    if (!Platform.isAndroid || _autoPipAvailable || _isInPip) return;
    if (state == AppLifecycleState.inactive &&
        (_controller?.value.isPlaying ?? false)) {
      _enterPip();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullUi = _scaffold(showControls: true);
    if (!Platform.isAndroid) return fullUi;

    // In PiP mode only the bare video is shown (no overlays).
    return PipWidget(
      onPipEntered: () => setState(() => _isInPip = true),
      onPipExited: () => setState(() => _isInPip = false),
      pipChild: _scaffold(showControls: false),
      child: fullUi,
    );
  }

  Widget _scaffold({required bool showControls}) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showControls ? _toggleControls : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null && showControls)
              _PlayerError(message: _error!, channelName: _channel.name)
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
            if (showControls && (_controlsVisible || _error != null))
              _ControlsOverlay(
                channelName: _channel.name,
                controller: ready ? controller : null,
                showSkip: _hasMultiple,
                showPip: Platform.isAndroid,
                onPrevious: () => _switchBy(-1),
                onNext: () => _switchBy(1),
                onPip: _enterPip,
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
  final bool showSkip;
  final bool showPip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPip;
  final VoidCallback onInteraction;

  const _ControlsOverlay({
    required this.channelName,
    required this.controller,
    required this.showSkip,
    required this.showPip,
    required this.onPrevious,
    required this.onNext,
    required this.onPip,
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
                if (showPip)
                  IconButton(
                    tooltip: 'Bild im Bild',
                    icon: const Icon(Icons.picture_in_picture_alt_rounded,
                        color: Colors.white),
                    onPressed: onPip,
                  ),
                const _LiveBadge(),
                const SizedBox(width: 16),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showSkip)
                  IconButton(
                    tooltip: 'Vorheriger Sender',
                    iconSize: 48,
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white),
                    onPressed: onPrevious,
                  ),
                const SizedBox(width: 16),
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
                        value.isPlaying
                            ? controller!.pause()
                            : controller!.play();
                        onInteraction();
                      },
                    ),
                  )
                else
                  const SizedBox(width: 72, height: 72),
                const SizedBox(width: 16),
                if (showSkip)
                  IconButton(
                    tooltip: 'Nächster Sender',
                    iconSize: 48,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white),
                    onPressed: onNext,
                  ),
              ],
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
