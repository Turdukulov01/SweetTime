import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Тонкая обёртка над Firebase Cloud Messaging для клиентского приложения.
///
/// Сервис намеренно «мягкий»: если Firebase не инициализирован (нет
/// google-services.json, эмулятор без Play Services, web без options) или
/// плагин бросает ошибку — методы возвращают null / пустой поток вместо
/// исключения. Пуш — вспомогательный, а не блокирующий путь: он никогда не
/// должен ронять запуск или сессию. Класс не зависит от Riverpod и UI.
class PushService {
  const PushService();

  /// Метка платформы для серверной ручки push-токенов.
  /// Push пока подключён только для Android; на неизвестных платформах
  /// безопасно отдаём `android`, чтобы не изобретать неподдерживаемые значения.
  String get platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    _ => 'android',
  };

  /// Запрашивает разрешение на уведомления и возвращает device-токен FCM.
  ///
  /// Возвращает null, если Firebase недоступен, разрешение не выдано или токен
  /// ещё не готов. Любая ошибка проглатывается — вызов безопасен даже без
  /// инициализированного Firebase (в т.ч. в unit-тестах).
  Future<String?> obtainToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Поток обновлений device-токена (FCM ротирует токены со временем).
  /// Пустые токены отфильтрованы; при недоступном Firebase — пустой поток.
  Stream<String> get tokenRefreshes {
    try {
      if (Firebase.apps.isEmpty) return const Stream<String>.empty();
      return FirebaseMessaging.instance.onTokenRefresh.where(
        (token) => token.isNotEmpty,
      );
    } catch (_) {
      return const Stream<String>.empty();
    }
  }
}
