import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeTopNotice;

/// Shows one compact transient notice at the top of the root overlay.
/// A newer notice replaces the previous one instead of building a queue.
void showTopNotice(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (_activeTopNotice?.mounted ?? false) _activeTopNotice!.remove();
  _activeTopNotice = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopNotice(
      message: message,
      actionLabel: actionLabel,
      onAction: () {
        if (entry.mounted) entry.remove();
        if (identical(_activeTopNotice, entry)) _activeTopNotice = null;
        onAction();
      },
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_activeTopNotice, entry)) _activeTopNotice = null;
      },
    ),
  );
  _activeTopNotice = entry;
  overlay.insert(entry);
}

class _TopNotice extends StatefulWidget {
  const _TopNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismissed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismissed;

  @override
  State<_TopNotice> createState() => _TopNoticeState();
}

class _TopNoticeState extends State<_TopNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    )..forward();
    _timer = Timer(const Duration(milliseconds: 2200), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top + 10;
    final offset = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: offset,
          child: Semantics(
            liveRegion: true,
            container: true,
            label: widget.message,
            child: Material(
              color: theme.colorScheme.inverseSurface,
              elevation: 8,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.inversePrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: widget.onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.inversePrimary,
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(widget.actionLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
