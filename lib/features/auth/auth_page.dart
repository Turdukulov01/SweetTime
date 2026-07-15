import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_state.dart';
import '../../shared/widgets/common.dart';

enum _AuthStep { signIn, contactPhone }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _phoneController = TextEditingController();
  late _AuthStep _step;
  bool _submitting = false;
  String? _error;

  String get _subscriberDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  String get _normalizedPhone => '+996$_subscriberDigits';

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _step = !state.isGuest && !state.hasContactPhone
        ? _AuthStep.contactPhone
        : _AuthStep.signIn;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = ref.read(appStateProvider.notifier);
    final result = await controller.loginWithGoogle();
    if (!mounted) return;
    switch (result) {
      case GoogleLoginResult.success:
        _finishAuthentication();
      case GoogleLoginResult.needsContact:
        setState(() {
          _step = _AuthStep.contactPhone;
          _submitting = false;
        });
      case GoogleLoginResult.cancelled:
        // Closing Google's account chooser is a normal user action.
        setState(() => _submitting = false);
      case GoogleLoginResult.notConfigured:
        setState(() {
          _submitting = false;
          _error = AppLocalizations.of(context).googleSignInUnavailableMessage;
        });
      case GoogleLoginResult.rejected:
        setState(() {
          _submitting = false;
          _error = AppLocalizations.of(context).googleSignInRejected;
        });
      case GoogleLoginResult.unavailable:
      case GoogleLoginResult.busy:
        setState(() {
          _submitting = false;
          _error = AppLocalizations.of(context).googleSignInFailed;
        });
    }
  }

  Future<void> _saveContactPhone() async {
    if (_submitting) return;
    if (_subscriberDigits.length != 9) {
      setState(
        () => _error = AppLocalizations.of(context).phoneIncompleteError,
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(appStateProvider.notifier)
        .saveContactPhone(_normalizedPhone);
    if (!mounted) return;
    if (result == ContactSaveResult.success) {
      _finishAuthentication();
      return;
    }
    setState(() {
      _submitting = false;
      _error = result == ContactSaveResult.rejected
          ? AppLocalizations.of(context).phoneIncompleteError
          : AppLocalizations.of(context).contactPhoneSaveFailed;
    });
  }

  void _finishAuthentication() {
    final controller = ref.read(appStateProvider.notifier);
    final destination = controller.takePendingAuthReturn();
    if (!mounted) return;
    context.go(destination?.location ?? '/profile');
  }

  void _cancelAndClose() {
    final controller = ref.read(appStateProvider.notifier);
    final destination = controller.takePendingAuthReturn();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      destination == AuthReturnDestination.checkout ? '/cart' : '/profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final appName = ref.watch(
      appStateProvider.select((state) => state.appName),
    );
    final contactStep = _step == _AuthStep.contactPhone;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(appStateProvider.notifier).cancelAuthReturn();
        } else {
          _cancelAndClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: strings.close,
            onPressed: _submitting ? null : _cancelAndClose,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: AppLogo(size: 56)),
            const SizedBox(height: 24),
            Text(
              strings.authSection,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contactStep
                  ? strings.contactPhoneTitle
                  : strings.signInTitle(appName),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              contactStep ? strings.contactPhoneIntro : strings.authIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (!contactStep) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _signInWithGoogle,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata_rounded),
                  label: Text(strings.continueWithGoogle),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sms_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.smsTemporarilyUnavailable,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.smsUnavailableHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _phoneController,
                enabled: !_submitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: const [_KyrgyzSubscriberNumberFormatter()],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _saveContactPhone(),
                decoration: InputDecoration(
                  labelText: strings.phoneNumber,
                  hintText: '555 123 456',
                  helperText: strings.kyrgyzPhoneFormatHint,
                  prefixText: '+996 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.contactPhoneUnverified,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _saveContactPhone,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.saveContactAndContinue),
              ),
            ],
            if (_error case final error?) _ErrorText(error),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.authProvidersDemoNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KyrgyzSubscriberNumberFormatter extends TextInputFormatter {
  const _KyrgyzSubscriberNumberFormatter();

  static final RegExp _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.length > 9 && digits.startsWith('996')) {
      digits = digits.substring(3);
    } else if (digits.length > 9 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 9) digits = digits.substring(0, 9);

    final groups = <String>[];
    for (var start = 0; start < digits.length; start += 3) {
      final end = start + 3 < digits.length ? start + 3 : digits.length;
      groups.add(digits.substring(start, end));
    }
    final formatted = groups.join(' ');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
