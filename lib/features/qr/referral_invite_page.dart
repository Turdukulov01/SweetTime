import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/referral_invite.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

class ReferralInvitePage extends ConsumerStatefulWidget {
  const ReferralInvitePage({
    super.key,
    required this.companyId,
    required this.rawCode,
  });

  final String companyId;
  final String rawCode;

  @override
  ConsumerState<ReferralInvitePage> createState() => _ReferralInvitePageState();
}

class _ReferralInvitePageState extends ConsumerState<ReferralInvitePage> {
  ReferralResult? _result;
  bool _applying = false;
  bool _valid = true;

  String? get _code => normalizeReferralCode(widget.rawCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final code = _code;
    if (!mounted) return;
    if (widget.companyId.toLowerCase() != referralCompanyId || code == null) {
      setState(() => _valid = false);
      return;
    }
    await ref.read(appStateProvider.notifier).rememberReferralInvite(code);
    if (!mounted) return;
    final state = ref.read(appStateProvider);
    if (state.accountReady) await _apply();
  }

  Future<void> _apply() async {
    final code = _code;
    if (code == null || _applying) return;
    final state = ref.read(appStateProvider);
    if (!state.accountReady) {
      context.push('/auth?referral=${Uri.encodeQueryComponent(code)}');
      return;
    }
    setState(() {
      _applying = true;
      _result = null;
    });
    final result = await ref
        .read(appStateProvider.notifier)
        .applyReferral(code);
    if (!mounted) return;
    setState(() {
      _applying = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appStateProvider.select((value) => value.accountReady), (
      previous,
      next,
    ) {
      if (next && previous != true && _valid && !_applying && _result == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _apply();
        });
      }
    });
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(appStateProvider);
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.close),
          tooltip: strings.close,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: AppLogo(size: 72)),
          const SizedBox(height: 28),
          Text(
            strings.invitedEyebrow,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.invitedTitle(state.appName),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            strings.invitedMessage(state.referralInvitedBonus),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          if (!_valid)
            _InviteResult(
              icon: Icons.link_off,
              title: strings.referralResultTitle(
                ReferralResult.invalidCode,
                invitedBonus: state.referralInvitedBonus,
              ),
              message: strings.referralResultMessage(
                ReferralResult.invalidCode,
                inviterBonus: state.referralInviterBonus,
              ),
            )
          else if (_applying)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(strings.activatingInvite)),
                  ],
                ),
              ),
            )
          else if (result != null)
            _InviteResult(
              icon: result.isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              title: strings.referralResultTitle(
                result,
                invitedBonus: state.referralInvitedBonus,
              ),
              message: strings.referralResultMessage(
                result,
                inviterBonus: state.referralInviterBonus,
              ),
            ),
          const SizedBox(height: 20),
          if (_valid && !_applying && result == null)
            FilledButton.icon(
              onPressed: _apply,
              icon: Icon(state.accountReady ? Icons.redeem : Icons.login),
              label: Text(
                state.accountReady
                    ? strings.activateFriendCode
                    : strings.signInAndGetPoints,
              ),
            ),
          if (result == ReferralResult.networkError) ...[
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.refresh),
              label: Text(strings.retry),
            ),
            const SizedBox(height: 10),
          ],
          if (result != null || !_valid)
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: Text(strings.goToHome),
            ),
        ],
      ),
    );
  }
}

class _InviteResult extends StatelessWidget {
  const _InviteResult({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
