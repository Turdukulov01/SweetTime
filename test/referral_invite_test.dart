import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/core/api_client.dart';
import 'package:sweettime/core/auth_store.dart';
import 'package:sweettime/core/google_identity.dart';
import 'package:sweettime/core/referral_invite.dart';
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';

void main() {
  group('referral invite links', () {
    test('builds the canonical HTTPS invitation', () {
      expect(
        referralInviteUrl('sweett-ab12cd'),
        'https://lnp-corporation.duckdns.org/invite/sweettime/SWEETT-AB12CD',
      );
    });

    test('parses plain, legacy QR and HTTPS forms', () {
      expect(normalizeReferralCode('sweett-ab12cd'), 'SWEETT-AB12CD');
      expect(
        normalizeReferralCode('SWEETTIME:REF:SWEETT-AB12CD'),
        'SWEETT-AB12CD',
      );
      expect(
        normalizeReferralCode(
          'https://lnp-corporation.duckdns.org/invite/sweettime/SWEETT-AB12CD',
        ),
        'SWEETT-AB12CD',
      );
    });

    test('rejects foreign and malformed invitations', () {
      expect(
        normalizeReferralCode(
          'https://example.com/invite/sweettime/SWEETT-AB12CD',
        ),
        isNull,
      );
      expect(
        normalizeReferralCode(
          'https://lnp-corporation.duckdns.org/invite/coffeego/SWEETT-AB12CD',
        ),
        isNull,
      );
      expect(normalizeReferralCode('!'), isNull);
    });
  });

  test('controller persists an invite until referral completion', () async {
    final store = _MemoryReferralInviteStore();
    final controller = AppStateController(referralInviteStore: store);
    addTearDown(controller.dispose);

    expect(await controller.rememberReferralInvite('sweett-ab12cd'), isTrue);
    expect(await controller.pendingReferralInvite(), 'SWEETT-AB12CD');

    await controller.clearPendingReferralInvite();
    expect(await controller.pendingReferralInvite(), isNull);
  });

  test('company config keeps server-owned referral bonuses', () {
    final config = CompanyConfig.fromJson({
      'appName': 'SweetTime',
      'referral': {'invitedBonus': 75, 'inviterBonus': 125},
    });

    expect(config.invitedBonus, 75);
    expect(config.inviterBonus, 125);
    final cached = CompanyConfig.fromJson(config.toJson());
    expect(cached.invitedBonus, 75);
    expect(cached.inviterBonus, 125);
  });

  test('concurrent referral activation sends one server request', () async {
    final api = _ReferralApi();
    final controller = AppStateController(
      api: api,
      authStore: _MemoryAuthStore(),
      googleIdentity: _GoogleIdentity(),
      referralInviteStore: _MemoryReferralInviteStore(),
    );
    addTearDown(controller.dispose);

    expect(await controller.loginWithGoogle(), GoogleLoginResult.success);
    final first = controller.applyReferral('SWEETT-AB12CD');
    final second = controller.applyReferral('SWEETT-AB12CD');
    await Future<void>.delayed(Duration.zero);
    expect(api.redeemCalls, 1);

    api.completeSuccess();
    expect(await first, ReferralResult.success);
    expect(await second, ReferralResult.success);
    expect(
      await controller.applyReferral('SWEETT-AB12CD'),
      ReferralResult.success,
    );
    expect(api.redeemCalls, 1);
  });
}

class _MemoryReferralInviteStore implements ReferralInviteStore {
  String? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String code) async {
    value = code;
  }
}

class _MemoryAuthStore implements AuthStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}

class _GoogleIdentity implements GoogleIdentityProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<GoogleIdentityResult> authenticate() async =>
      const GoogleIdentityResult.success('google-token');

  @override
  Future<void> signOut() async {}
}

class _ReferralApi extends ApiClient {
  static const profile = CustomerProfile(
    id: 'customer-1',
    phone: '+996700123456',
    firstName: 'Test',
    lastName: 'Customer',
    birthDate: null,
    points: 0,
    referralCode: 'SWEETT-OWN123',
    invitedByCode: null,
  );

  final Completer<ApiResult<ReferralOutcome>> _redeem = Completer();
  int redeemCalls = 0;

  void completeSuccess() {
    _redeem.complete(
      const ApiResult<ReferralOutcome>.ok(
        ReferralOutcome(
          profile: CustomerProfile(
            id: 'customer-1',
            phone: '+996700123456',
            firstName: 'Test',
            lastName: 'Customer',
            birthDate: null,
            points: 75,
            referralCode: 'SWEETT-OWN123',
            invitedByCode: 'SWEETT-AB12CD',
          ),
        ),
      ),
    );
  }

  @override
  Future<ApiResult<CustomerSession>> googleSignIn(String idToken) async =>
      const ApiResult<CustomerSession>.ok(
        CustomerSession(
          tokens: TokenPair(accessToken: 'access', refreshToken: 'refresh'),
          profile: profile,
        ),
      );

  @override
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async => const ApiResult<List<String>>.ok([]);

  @override
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) async => const ApiResult<List<OrderHistoryEntry>>.ok([]);

  @override
  Future<ApiResult<RecurringOrder?>> fetchCustomerRecurring(
    String accessToken,
  ) async => const ApiResult<RecurringOrder?>.ok(null);

  @override
  Future<ApiResult<ReferralOutcome>> redeemReferral(
    String accessToken,
    String code,
  ) {
    redeemCalls++;
    return _redeem.future;
  }
}
