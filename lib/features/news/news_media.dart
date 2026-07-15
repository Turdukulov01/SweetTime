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

  @override
  State<NewsMediaView> createState() => _NewsMediaViewState();
}

class _NewsMediaViewState extends State<NewsMediaView>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _controllerUrl;
  bool _initializing = false;
  bool _videoFailed = false;

  bool get _shouldLoadVideo =>
      widget.mediaType == NewsMediaType.video &&
      widget.allowVideo &&
      widget.isActive &&
      (widget.url?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant NewsMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.allowVideo != widget.allowVideo ||
        oldWidget.isActive != widget.isActive) {
      _syncVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  Future<void> _syncVideo() async {
    final desiredUrl = widget.url?.trim();
    if (!_shouldLoadVideo) {
      await _disposeController();
      return;
    }
    if (_controllerUrl == desiredUrl && _controller != null) return;
    await _disposeController();
    if (!mounted || !_shouldLoadVideo) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(desiredUrl!));
    _controller = controller;
    _controllerUrl = desiredUrl;
    setState(() {
      _initializing = true;
      _videoFailed = false;
    });
    try {
      await controller.initialize().timeout(const Duration(seconds: 12));
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      setState(() => _initializing = false);
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

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _controllerUrl = null;
    if (controller != null) {
      await controller.pause();
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose();
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
      media = Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller!.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Center(
            child: IconButton.filledTonal(
              tooltip: controller.value.isPlaying
                  ? AppLocalizations.of(context).pauseVideo
                  : AppLocalizations.of(context).playVideo,
              onPressed: () async {
                controller.value.isPlaying
                    ? await controller.pause()
                    : await controller.play();
                if (mounted) setState(() {});
              },
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ),
        ],
      );
    } else if (widget.mediaType == NewsMediaType.image &&
        (widget.url?.trim().isNotEmpty ?? false)) {
      media = _NetworkMediaImage(url: widget.url!);
    } else if (widget.mediaType == NewsMediaType.video) {
      final preview = widget.thumbnailUrl?.trim();
      media = Stack(
        fit: StackFit.expand,
        children: [
          if (preview != null && preview.isNotEmpty)
            _NetworkMediaImage(url: preview)
          else
            _FallbackMedia(icon: widget.fallbackIcon),
          if (_initializing)
            const Center(child: CircularProgressIndicator.adaptive())
          else
            Center(
              child: Icon(
                _videoFailed ? Icons.videocam_off_outlined : Icons.play_circle,
                size: 52,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
              ),
            ),
        ],
      );
    } else if (widget.assetImage != null) {
      media = Image.asset(widget.assetImage!, fit: BoxFit.cover);
    } else {
      media = _FallbackMedia(icon: widget.fallbackIcon);
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(borderRadius: widget.borderRadius, child: media),
    );
  }
}

class _NetworkMediaImage extends StatelessWidget {
  const _NetworkMediaImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * ratio).round().clamp(320, 1600);
    return Image.network(
      url,
      fit: BoxFit.cover,
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
