import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/core/api_client.dart';

void main() {
  test('release without API_BASE uses the production HTTPS origin', () {
    expect(
      resolveApiBase(configured: '', releaseMode: true),
      'https://lnp-corporation.duckdns.org',
    );
  });

  test('debug without API_BASE keeps the local development origin', () {
    expect(
      resolveApiBase(configured: '', releaseMode: false),
      'http://127.0.0.1:8010',
    );
  });

  test('an explicit API_BASE overrides either build mode', () {
    expect(
      resolveApiBase(
        configured: ' https://staging.example.test/ ',
        releaseMode: true,
      ),
      'https://staging.example.test/',
    );
  });
}
