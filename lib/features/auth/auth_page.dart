import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/app_state.dart';
import '../../shared/demo_data.dart';
import '../../shared/widgets/common.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeStep = false;

  /// Проверка кода уходит на сервер: блокируем повторные нажатия.
  bool _submitting = false;
  String? _error;

  String get _subscriberDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  String get _normalizedPhone => '+996$_subscriberDigits';

  String get _displayPhone => '+996 ${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _requestCode() {
    if (_subscriberDigits.length != 9) {
      setState(
        () => _error = AppLocalizations.of(context).phoneIncompleteError,
      );
      return;
    }
    // Просим сервер выслать код. SMS-провайдера нет (код всегда демо-1111),
    // поэтому шаг ввода кода не ждёт ответа и работает офлайн.
    unawaited(ref.read(appStateProvider.notifier).requestOtp(_normalizedPhone));
    setState(() {
      _error = null;
      _codeStep = true;
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final strings = AppLocalizations.of(context);
    final controller = ref.read(appStateProvider.notifier);
    setState(() {
      _error = null;
      _submitting = true;
    });

    final signedIn = await controller.loginWithOtp(
      _normalizedPhone,
      _codeController.text.trim(),
    );
    if (!mounted) return;
    if (!signedIn) {
      setState(() {
        _submitting = false;
        _error = strings.invalidDemoCodeError(DemoData.demoOtpCode);
      });
      return;
    }

    setState(() => _submitting = false);
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

  void _showGoogleSignInUnavailable() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).googleSignInUnavailableMessage,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final appName = ref.watch(
      appStateProvider.select((state) => state.appName),
    );
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
            onPressed: _cancelAndClose,
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
              _codeStep ? strings.smsCodeTitle : strings.signInTitle(appName),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _codeStep
                  ? strings.demoCodeSent(_displayPhone, DemoData.demoOtpCode)
                  : strings.authIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (!_codeStep) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: const [_KyrgyzSubscriberNumberFormatter()],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _requestCode(),
                decoration: InputDecoration(
                  labelText: strings.phoneNumber,
                  hintText: '555 123 456',
                  helperText: strings.kyrgyzPhoneFormatHint,
                  prefixText: '+996 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              if (_error != null) _ErrorText(_error!),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _requestCode,
                icon: const Icon(Icons.sms_outlined),
                label: Text(strings.requestCode),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showGoogleSignInUnavailable,
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  label: Text(strings.continueWithGoogle),
                ),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(4),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(hintText: '••••'),
              ),
              if (_error != null) _ErrorText(_error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _confirm,
                child: Text(strings.confirmAndSignIn),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _codeStep = false;
                        _codeController.clear();
                        _error = null;
                      }),
                icon: const Icon(Icons.arrow_back),
                label: Text(strings.changePhoneNumber),
              ),
            ],
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

    // Autofill and paste may include the country code even though +996 is fixed
    // in the field UI. Keep only the nine-digit subscriber number.
    if (digits.length > 9 && digits.startsWith('996')) {
      digits = digits.substring(3);
    } else if (digits.length > 9 && digits.startsWith('0')) {
      // A copied local Kyrgyz number is often written as 0XXX XXX XXX.
      // The field already owns +996, so discard the trunk prefix.
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
