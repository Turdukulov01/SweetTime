import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final entries = [
      (strings.profileFaqPointsQuestion, strings.profileFaqPointsAnswer),
      (strings.profileFaqOrderQuestion, strings.profileFaqOrderAnswer),
      (strings.profileFaqQrQuestion, strings.profileFaqQrAnswer),
      (strings.profileFaqEditQuestion, strings.profileFaqEditAnswer),
      (strings.profileFaqDeleteQuestion, strings.profileFaqDeleteAnswer),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(strings.profileFaqTitle)),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                minTileHeight: 56,
                title: Text(entry.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: double.infinity, child: Text(entry.$2)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
