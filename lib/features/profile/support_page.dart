import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.profileSupportTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.profileSupportDemoTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.profileSupportDemoBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    enabled: false,
                    minTileHeight: 56,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(strings.profileSupportChat),
                    subtitle: Text(strings.profileSupportUnavailable),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    enabled: false,
                    minTileHeight: 56,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(strings.profileSupportPhone),
                    subtitle: Text(strings.profileSupportUnavailable),
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
