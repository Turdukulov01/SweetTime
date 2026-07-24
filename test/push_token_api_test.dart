import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sweettime/core/api_client.dart';

void main() {
  test('registerPushToken PUTs token + platform and treats 204 as success', () async {
    late http.Request captured;
    final api = ApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    final result = await api.registerPushToken(
      'access-token-1',
      token: 'fcm-device-1',
      platform: 'android',
    );

    expect(result.isOk, isTrue);
    expect(captured.method, 'PUT');
    expect(
      captured.url.path,
      '/api/companies/sweettime/auth/customer/me/push-tokens',
    );
    expect(captured.headers['authorization'], 'Bearer access-token-1');
    expect(
      jsonDecode(captured.body),
      {'token': 'fcm-device-1', 'platform': 'android'},
    );
  });

  test('removePushToken POSTs to the remove path and treats 204 as success', () async {
    late http.Request captured;
    final api = ApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    final result = await api.removePushToken(
      'access-token-2',
      token: 'fcm-device-2',
      platform: 'android',
    );

    expect(result.isOk, isTrue);
    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/companies/sweettime/auth/customer/me/push-tokens/remove',
    );
    expect(captured.headers['authorization'], 'Bearer access-token-2');
    expect(
      jsonDecode(captured.body),
      {'token': 'fcm-device-2', 'platform': 'android'},
    );
  });

  test('401 is reported as rejected so a token refresh can retry', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 401)),
    );

    final result = await api.registerPushToken(
      'stale',
      token: 'fcm-device-3',
      platform: 'android',
    );

    expect(result.isOk, isFalse);
    expect(result.isRejected, isTrue);
  });

  test('a server error is not mistaken for a successful registration', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('boom', 500)),
    );

    final result = await api.removePushToken(
      'access-token-4',
      token: 'fcm-device-4',
      platform: 'android',
    );

    expect(result.isOk, isFalse);
    expect(result.isRejected, isFalse);
  });
}
