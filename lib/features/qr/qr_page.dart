import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

const _qrPrefix = 'SWEETTIME:REF:';

/// Вкладка «QR»: личный QR (лояльность + рефералка) и сканер кода друга.
class QrPage extends ConsumerWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(appStateProvider.select((s) => s.isGuest));
    final strings = AppLocalizations.of(context);

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.qr)),
        body: EmptyState(
          icon: Icons.qr_code_2,
          title: strings.qrGuestTitle,
          message: strings.qrGuestMessage,
          action: FilledButton(
            onPressed: () => context.push('/auth'),
            child: Text(strings.login),
          ),
        ),
      );
    }

    // Диплинк на вкладку сканера: /qr?tab=scan (пуши, промо-ссылки).
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];

    return DefaultTabController(
      length: 2,
      initialIndex: tab == 'scan' ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.qr),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.qr_code_2), text: strings.myQr),
              Tab(icon: const Icon(Icons.qr_code_scanner), text: strings.scan),
            ],
          ),
        ),
        body: const TabBarView(children: [_MyQrTab(), _ScanTab()]),
      ),
    );
  }
}

class _MyQrTab extends ConsumerWidget {
  const _MyQrTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final code = formatUserCode(state.userCode);
    final strings = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Text(
            formatPoints(state.points, strings.language),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              strings.myQrDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          // Белая подложка — чтобы QR читался сканером и в тёмной теме.
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: QrImageView(
              data: '$_qrPrefix${state.userCode}',
              version: QrVersions.auto,
              size: 230,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF251713),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF251713),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              IconButton(
                tooltip: strings.copyCode,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: state.userCode));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(strings.codeCopied)));
                },
                icon: const Icon(Icons.copy, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            strings.referralBonus(Referral.invitedBonus, Referral.inviterBonus),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanTab extends ConsumerStatefulWidget {
  const _ScanTab();

  @override
  ConsumerState<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends ConsumerState<_ScanTab>
    with WidgetsBindingObserver {
  final _codeController = TextEditingController();
  final _scannerController = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  TabController? _tabController;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  Future<void> _scannerOperations = Future<void>.value();
  bool _branchActive = false;
  bool _initialSyncScheduled = false;
  bool _initialSyncComplete = false;
  bool _syncEnqueued = false;
  bool _syncRequested = false;
  bool _disposing = false;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextTabController = DefaultTabController.of(context);
    if (!identical(_tabController, nextTabController)) {
      _tabController?.removeListener(_handleTabChanged);
      _tabController = nextTabController..addListener(_handleTabChanged);
    }

    _branchActive = TickerMode.valuesOf(context).enabled;
    _requestScannerSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _requestScannerSync();
  }

  void _handleTabChanged() {
    _requestScannerSync();
  }

  bool get _shouldRunScanner =>
      !_disposing &&
      _lifecycleState == AppLifecycleState.resumed &&
      _branchActive &&
      _tabController?.index == 1;

  void _requestScannerSync() {
    if (_disposing) return;

    if (!_initialSyncScheduled) {
      _initialSyncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposing || !mounted) return;
        _initialSyncComplete = true;
        _enqueueScannerSync();
      });
      return;
    }

    if (!_initialSyncComplete) return;
    _enqueueScannerSync();
  }

  void _enqueueScannerSync() {
    if (_disposing) return;

    _syncRequested = true;
    if (_syncEnqueued) return;

    _syncEnqueued = true;
    _scannerOperations = _scannerOperations.then((_) => _drainScannerSync());
  }

  Future<void> _drainScannerSync() async {
    try {
      while (_syncRequested && !_disposing) {
        _syncRequested = false;
        if (_shouldRunScanner) {
          await _scannerController.start();
        } else {
          await _scannerController.stop();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Не удалось обновить состояние QR-сканера: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _syncEnqueued = false;
      if (_syncRequested && !_disposing) {
        _enqueueScannerSync();
      }
    }
  }

  Future<void> _disposeScanner() async {
    await _scannerOperations;
    try {
      await _scannerController.stop();
    } catch (error, stackTrace) {
      debugPrint('Не удалось остановить QR-сканер: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      try {
        await _scannerController.dispose();
      } catch (error, stackTrace) {
        debugPrint('Не удалось освободить QR-сканер: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _syncRequested = false;
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.removeListener(_handleTabChanged);
    _tabController = null;
    _codeController.dispose();
    unawaited(_disposeScanner());
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).torchError)),
      );
    }
  }

  Widget _buildTorchButton() {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _scannerController,
      builder: (context, state, child) {
        final strings = AppLocalizations.of(context);
        if (!state.isInitialized || !state.isRunning) {
          return const SizedBox.shrink();
        }

        final isUnavailable = state.torchState == TorchState.unavailable;
        final isOn = state.torchState == TorchState.on;
        final label = switch (state.torchState) {
          TorchState.on => strings.torchOff,
          TorchState.off => strings.torchOn,
          TorchState.auto => strings.torchAuto,
          TorchState.unavailable => strings.torchUnavailable,
        };
        final icon = switch (state.torchState) {
          TorchState.on => Icons.flash_on,
          TorchState.off => Icons.flash_off,
          TorchState.auto => Icons.flash_auto,
          TorchState.unavailable => Icons.no_flash,
        };

        return Semantics(
          button: true,
          enabled: !isUnavailable,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: isOn
                ? Theme.of(context).colorScheme.primary
                : Colors.black.withValues(alpha: 0.62),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: isUnavailable ? null : _toggleTorch,
              tooltip: label,
              color: isOn
                  ? Theme.of(context).colorScheme.onPrimary
                  : Colors.white,
              disabledColor: Colors.white54,
              icon: Icon(icon),
            ),
          ),
        );
      },
    );
  }

  Future<void> _apply(String raw) async {
    if (_handling) return;
    _handling = true;
    final payload = raw.startsWith(_qrPrefix)
        ? raw.substring(_qrPrefix.length)
        : raw;
    final result = ref.read(appStateProvider.notifier).applyReferral(payload);
    final strings = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          result.isSuccess ? Icons.check_circle : Icons.info_outline,
          color: result.isSuccess
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
          size: 40,
        ),
        title: Text(strings.referralResultTitle(result)),
        content: Text(strings.referralResultMessage(result)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.understood),
          ),
        ],
      ),
    );
    _handling = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          strings.scanFriendQr,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final value = capture.barcodes.isEmpty
                        ? null
                        : capture.barcodes.first.rawValue;
                    if (value != null) _apply(value);
                  },
                  errorBuilder: (context, error, child) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_photography_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.cameraUnavailable,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(right: 12, bottom: 12, child: _buildTorchButton()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(strings.enterFriendCode, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(hintText: '512 347'),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => _apply(_codeController.text),
              // конечная minWidth: кнопка стоит в Row (тема задаёт fromHeight = ∞)
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              child: Text(strings.apply),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.referralSafety,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
