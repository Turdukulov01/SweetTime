import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/referral_invite.dart';
import '../../core/system_share.dart';
import '../../shared/app_models.dart';
import '../../shared/app_state.dart';

class LoyaltyPage extends ConsumerWidget {
  const LoyaltyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.profilePointsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _BonusCard(points: state.points),
            const SizedBox(height: 16),
            _LoyaltyRules(
              earnRate: state.loyaltyEarnRate,
              maxSpendShare: state.loyaltyMaxSpendShare,
            ),
            const SizedBox(height: 16),
            _ReferralCard(
              code: state.userCode,
              appName: state.appName,
              invitedBonus: state.referralInvitedBonus,
              inviterBonus: state.referralInviterBonus,
            ),
          ],
        ),
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.profileBonusBalance,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPoints(points, strings.language),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '= ${formatSom(points * Loyalty.pointValueKgs, strings.language)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}

class _LoyaltyRules extends StatelessWidget {
  const _LoyaltyRules({required this.earnRate, required this.maxSpendShare});

  final double earnRate;
  final double maxSpendShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final rules = [
      strings.profilePointValueRule(
        formatPoints(1, strings.language),
        formatSom(Loyalty.pointValueKgs, strings.language),
      ),
      strings.profileEarnRule((earnRate * 100).round()),
      strings.profileSpendRule((maxSpendShare * 100).round()),
      strings.profileExpiryRule(months: Loyalty.expiryMonths),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.profileLoyaltyRules,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rule, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.code,
    required this.appName,
    required this.invitedBonus,
    required this.inviterBonus,
  });

  final String code;
  final String appName;
  final int invitedBonus;
  final int inviterBonus;

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkCopied)),
    );
  }

  Future<void> _shareLink(
    BuildContext context,
    String appName,
    String link,
  ) async {
    final strings = AppLocalizations.of(context);
    final shared = await SystemShare.text(
      strings.inviteShareText(appName, invitedBonus, link),
      subject: strings.profileInviteFriend,
    );
    if (!shared && context.mounted) await _copyLink(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final link = referralInviteUrl(code);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.profileInviteFriend,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              strings.profileReferralDescription(
                invitedPoints: formatPoints(invitedBonus, strings.language),
                inviterPoints: formatPoints(inviterBonus, strings.language),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    formatUserCode(code),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyLink(context, link),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(strings.copyLink),
                ),
                FilledButton.icon(
                  onPressed: () => _shareLink(context, appName, link),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(strings.shareInvite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
