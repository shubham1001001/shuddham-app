import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Centralized API request and response logger for Flutter application.
/// Formats request details, payloads, response status codes, and bodies
/// so they appear cleanly in Android logcat and terminal debug outputs.
class ApiLogger {
  ApiLogger._();

  static void logRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ 📡 [API REQUEST] $method $uri');
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('║ 📋 Headers: ${jsonEncode(headers)}');
    }
    if (body != null) {
      if (body is Map || body is List) {
        buffer.writeln('║ 📦 Payload: ${jsonEncode(body)}');
      } else {
        buffer.writeln('║ 📦 Payload: $body');
      }
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _print(buffer.toString());
  }

  static void logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    String? responseBody,
    Duration? duration,
  }) {
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ $icon [API RESPONSE] $statusCode | $method $uri${duration != null ? ' (${duration.inMilliseconds}ms)' : ''}');
    if (responseBody != null && responseBody.isNotEmpty) {
      buffer.writeln('║ 📄 Body: $responseBody');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _print(buffer.toString());
  }

  static void logError({
    required String method,
    required Uri uri,
    required dynamic error,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════════════════════════');
    buffer.writeln('║ ⚠️ [API NETWORK/ERROR] $method $uri');
    buffer.writeln('║ 💥 Error: $error');
    buffer.writeln('╚══════════════════════════════════════════════════════════════════');
    _print(buffer.toString());
  }

  static void _print(String text) {
    for (final line in text.split('\n')) {
      if (line.isNotEmpty) {
        debugPrint(line);
      }
    }
  }
}
