import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization/app_localizations.dart';
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
            _ReferralCard(code: formatUserCode(state.userCode)),
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
  const _ReferralCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
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
                invitedPoints: formatPoints(
                  Referral.invitedBonus,
                  strings.language,
                ),
                inviterPoints: formatPoints(
                  Referral.inviterBonus,
                  strings.language,
                ),
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
                  child: Text(code, style: theme.textTheme.titleSmall),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(strings.codeCopied)));
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(strings.copyCode),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
