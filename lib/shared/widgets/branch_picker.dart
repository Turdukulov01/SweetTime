import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../app_models.dart';

/// Shared branch picker used before the customer invests time configuring an
/// item. When [availableBranchIds] is supplied, incompatible branches remain
/// visible for context but cannot be selected.
Future<Branch?> showBranchPicker(
  BuildContext context, {
  required List<Branch> branches,
  required Branch selectedBranch,
  Set<String>? availableBranchIds,
  String? title,
}) {
  return showModalBottomSheet<Branch>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final strings = AppLocalizations.of(sheetContext);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: branches.length > 4 ? 0.72 : 0.52,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title ?? strings.chooseBranch,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: branches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  final stocksProduct =
                      availableBranchIds == null ||
                      availableBranchIds.contains(branch.id);
                  final compatible = branch.isOpen && stocksProduct;
                  final selected = branch.id == selectedBranch.id;
                  return ListTile(
                    enabled: compatible,
                    leading: Icon(
                      compatible
                          ? Icons.storefront_outlined
                          : Icons.location_off_outlined,
                    ),
                    title: Text(branch.name.resolve(strings.language)),
                    subtitle: Text(
                      !branch.isOpen
                          ? strings.branchClosed
                          : compatible
                          ? '${branch.address.resolve(strings.language)} · ${branch.hours}'
                          : strings.branchDoesNotStockProduct,
                    ),
                    trailing: selected && compatible
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : compatible
                        ? const Icon(Icons.chevron_right)
                        : null,
                    onTap: compatible
                        ? () => Navigator.of(sheetContext).pop(branch)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
