import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';

class NewsMediaView extends StatefulWidget {
  const NewsMediaView({
    super.key,
    required this.mediaType,
    required this.url,
    this.thumbnailUrl,
    this.assetImage,
    this.allowVideo = false,
    this.isActive = true,
    this.aspectRatio = 16 / 9,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.fallbackIcon = Icons.auto_awesome,
    this.fit = BoxFit.cover,
    this.expand = false,
    this.backgroundColor,
    this.autoPlay = false,
    this.playbackPaused = false,
    this.showPlaybackControls = true,
    this.tapToToggleMute = false,
    this.initialMuted = false,
    this.onVideoReady,
    this.onVideoProgress,
    this.onVideoEnded,
  });

  final NewsMediaType mediaType;
  final String? url;
  final String? thumbnailUrl;
  final String? assetImage;
  final bool allowVideo;
  final bool isActive;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final BoxFit fit;

  /// Fills the constraints supplied by the parent instead of imposing a 16:9
  /// card. Stories and the post detail viewer use this for a true media stage.
  final bool expand;
  final Color? backgroundColor;
  final bool autoPlay;
  final bool playbackPaused;
  final bool showPlaybackControls;
  final bool tapToToggleMute;
  final bool initialMuted;
  final ValueChanged<Duration>? onVideoReady;
  final void Function(Duration position, Duration duration)? onVideoProgress;
  final VoidCallback? onVideoEnded;

  @override
  State<NewsMediaView> createState() => _NewsMediaViewState();
}

class _NewsMediaViewState extends State<NewsMediaView>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _controllerUrl;
  bool _initializing = false;
  bool _videoFailed = false;
  bool _muted = false;
  bool _completionReported = false;
  bool? _lastPlaying;

  bool get _shouldLoadVideo =>
      widget.mediaType == NewsMediaType.video &&
      widget.allowVideo &&
      widget.isActive &&
      (widget.url?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _muted = widget.initialMuted;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncVideo());
  }

  @override
  void didUpdateWidget(covariant NewsMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMuted != widget.initialMuted) {
      _muted = widget.initialMuted;
      unawaited(_controller?.setVolume(_muted ? 0 : 1));
    }
    if (oldWidget.url != widget.url ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.allowVideo != widget.allowVideo ||
        oldWidget.isActive != widget.isActive) {
      unawaited(_syncVideo());
    } else if (oldWidget.playbackPaused != widget.playbackPaused ||
        oldWidget.autoPlay != widget.autoPlay) {
      unawaited(_syncPlayback());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPlayback());
    } else {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _syncVideo() async {
    final desiredUrl = widget.url?.trim();
    if (!_shouldLoadVideo) {
      await _disposeController();
      return;
    }
    if (_controllerUrl == desiredUrl && _controller != null) {
      await _syncPlayback();
      return;
    }
    await _disposeController();
    if (!mounted || !_shouldLoadVideo) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(desiredUrl!));
    _controller = controller;
    _controllerUrl = desiredUrl;
    _completionReported = false;
    _lastPlaying = null;
    setState(() {
      _initializing = true;
      _videoFailed = false;
    });
    try {
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(_muted ? 0 : 1);
      controller.addListener(_handleVideoTick);
      setState(() {
        _initializing = false;
        _lastPlaying = controller.value.isPlaying;
      });
      widget.onVideoReady?.call(controller.value.duration);
      await _syncPlayback();
    } catch (_) {
      if (identical(_controller, controller)) {
        await _disposeController();
        if (mounted) {
          setState(() {
            _initializing = false;
            _videoFailed = true;
          });
        }
      }
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!widget.isActive || widget.playbackPaused) {
      await controller.pause();
    } else if (widget.autoPlay) {
      await controller.play();
    }
  }

  void _handleVideoTick() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    widget.onVideoProgress?.call(value.position, value.duration);

    if (_lastPlaying != value.isPlaying) {
      _lastPlaying = value.isPlaying;
      setState(() {});
    }

    final duration = value.duration;
    final completed =
        duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 90);
    if (completed && !_completionReported) {
      _completionReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVideoEnded?.call();
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (_completionReported ||
          controller.value.position >= controller.value.duration) {
        _completionReported = false;
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMuted() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _controllerUrl = null;
    _completionReported = false;
    _lastPlaying = null;
    if (controller != null) {
      controller.removeListener(_handleVideoTick);
      await controller.pause();
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_handleVideoTick);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    Widget media;
    if (widget.mediaType == NewsMediaType.video &&
        widget.allowVideo &&
        widget.isActive &&
        initialized) {
      final video = FittedBox(
        fit: widget.fit,
        alignment: Alignment.center,
        child: SizedBox(
          width: controller!.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
      media = Stack(
        fit: StackFit.expand,
        children: [
          if (widget.tapToToggleMute)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMuted,
              child: video,
            )
          else
            video,
          if (widget.showPlaybackControls)
            Center(
              child: IconButton.filled(
                tooltip: controller.value.isPlaying
                    ? AppLocalizations.of(context).pauseVideo
                    : AppLocalizations.of(context).playVideo,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.52),
                  foregroundColor: Colors.white,
                ),
                onPressed: _togglePlayback,
                iconSize: 34,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ),
          if (widget.tapToToggleMute)
            Positioned(
              right: 14,
              bottom: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    } else if (widget.mediaType == NewsMediaType.image &&
        (widget.url?.trim().isNotEmpty ?? false)) {
      media = _NetworkMediaImage(url: widget.url!, fit: widget.fit);
    } else if (widget.mediaType == NewsMediaType.video) {
      final preview = widget.thumbnailUrl?.trim();
      media = Stack(
        fit: StackFit.expand,
        children: [
          if (preview != null && preview.isNotEmpty)
            _NetworkMediaImage(url: preview, fit: widget.fit)
          else
            _FallbackMedia(icon: widget.fallbackIcon),
          if (_initializing)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Center(
              child: Icon(
                _videoFailed ? Icons.videocam_off_outlined : Icons.play_circle,
                size: 58,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
              ),
            ),
        ],
      );
    } else if (widget.assetImage != null) {
      media = Image.asset(widget.assetImage!, fit: widget.fit);
    } else {
      media = _FallbackMedia(icon: widget.fallbackIcon);
    }

    final stage = ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: widget.backgroundColor ?? Colors.transparent,
        child: SizedBox.expand(child: media),
      ),
    );
    if (widget.expand) return stage;
    return AspectRatio(aspectRatio: widget.aspectRatio, child: stage);
  }
}

class _NetworkMediaImage extends StatelessWidget {
  const _NetworkMediaImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * ratio).round().clamp(320, 2000);
    return Image.network(
      url,
      fit: fit,
      alignment: Alignment.center,
      cacheWidth: cacheWidth,
      frameBuilder: (context, child, frame, synchronouslyLoaded) {
        if (synchronouslyLoaded || frame != null) return child;
        return const Center(child: CircularProgressIndicator.adaptive());
      },
      errorBuilder: (context, error, stackTrace) =>
          const _FallbackMedia(icon: Icons.broken_image_outlined),
    );
  }
}

class _FallbackMedia extends StatelessWidget {
  const _FallbackMedia({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 50, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
