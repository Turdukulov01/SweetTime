import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/referral_invite.dart';
import '../../core/system_share.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

const _loyaltyQrPrefix = 'SWEETTIME:LOYALTY:';

/// Loyalty identity, a shareable referral link and friend-code activation are
/// intentionally separate: each QR now has one clear purpose.
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
      length: 3,
      initialIndex: tab == 'scan' ? 2 : (tab == 'invite' ? 1 : 0),
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.qr),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              Tab(icon: const Icon(Icons.qr_code_2), text: strings.myQr),
              Tab(
                icon: const Icon(Icons.group_add_outlined),
                text: strings.invite,
              ),
              Tab(icon: const Icon(Icons.qr_code_scanner), text: strings.scan),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MyQrTab(), _InviteQrTab(), _ScanTab()],
        ),
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
        _ResponsiveQrCode(data: '$_loyaltyQrPrefix${state.userCode}'),
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
      ],
    );
  }
}

class _InviteQrTab extends ConsumerWidget {
  const _InviteQrTab();

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).codeCopied)),
    );
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkCopied)),
    );
  }

  Future<void> _share(
    BuildContext context,
    String appName,
    int invitedBonus,
    String link,
  ) async {
    final strings = AppLocalizations.of(context);
    final message = strings.inviteShareText(appName, invitedBonus, link);
    final shared = await SystemShare.text(message, subject: strings.invite);
    if (!shared && context.mounted) await _copy(context, link);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final link = referralInviteUrl(state.userCode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          strings.inviteFriendTitle(state.appName),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  strings.inviteQrDescription(state.appName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ResponsiveQrCode(data: link),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                formatUserCode(state.userCode),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: strings.copyCode,
                onPressed: () => _copyCode(context, state.userCode),
                icon: const Icon(Icons.content_copy_rounded, size: 20),
              ),
            ],
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              strings.referralBonus(
                state.referralInvitedBonus,
                state.referralInviterBonus,
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: () => _share(
              context,
              state.appName,
              state.referralInvitedBonus,
              link,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(strings.shareInvite),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton.icon(
            onPressed: () => _copy(context, link),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(strings.copyLink),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveQrCode extends StatelessWidget {
  const _ResponsiveQrCode({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 32)
            .clamp(248.0, 304.0)
            .toDouble();
        return Center(
          // Белая подложка обязательна для стабильного считывания QR в обеих
          // темах. Размер адаптируется к ширине, но не раздувается на планшете.
          child: RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: qrSize,
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
        );
      },
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
      _tabController?.index == 2;

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
    final result = await ref.read(appStateProvider.notifier).applyReferral(raw);
    if (!mounted) {
      _handling = false;
      return;
    }
    final strings = AppLocalizations.of(context);
    final state = ref.read(appStateProvider);
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
        title: Text(
          strings.referralResultTitle(
            result,
            invitedBonus: state.referralInvitedBonus,
          ),
        ),
        content: Text(
          strings.referralResultMessage(
            result,
            inviterBonus: state.referralInviterBonus,
          ),
        ),
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
                // Код теперь буквенно-цифровой с дефисом (SWEETT-XXXXXX), а не
                // 6 цифр: разрешаем A–Z, 0–9 и «-», приводим к верхнему регистру.
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                  LengthLimitingTextInputFormatter(24),
                  _UpperCaseFormatter(),
                ],
                decoration: const InputDecoration(hintText: 'SWEETT-AB12CD'),
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

/// Приводит вводимый код к верхнему регистру, сохраняя позицию курсора.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
