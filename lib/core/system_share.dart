import 'package:flutter/services.dart';

class SystemShare {
  const SystemShare._();

  static const _channel = MethodChannel('kg.sweettime.app/share');

  /// Opens the native share sheet. Returns false when the platform bridge is
  /// unavailable so the caller can fall back to copying the link.
  static Future<bool> text(String text, {String? subject}) async {
    try {
      return await _channel.invokeMethod<bool>('shareText', {
            'text': text,
            'subject': ?subject,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
