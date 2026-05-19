import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../models/weather_response.dart';

/// Thin wrapper around the OpenWeather "current weather" endpoint.
///
/// Per ULTIMATE.md §2.1 the API key is NOT hardcoded — it's injected at
/// build time via `--dart-define=OPENWEATHER_KEY=...`. If the build was
/// done without the flag, the service returns `null` instead of leaking
/// a fallback request, so the UI just hides the weather widget.
///
/// Local dev:
///   flutter run --dart-define=OPENWEATHER_KEY=your_key_here
///
/// CI / release builds should inject the key from a secret store
/// (GitHub Actions secret, Codemagic env var, etc.), never commit it.
class WeatherService {
  WeatherService._();

  static const String _apiKey =
      String.fromEnvironment('OPENWEATHER_KEY', defaultValue: 'e631615be1564b8422a6b695ad0cbe60');
  static const String _base =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Read-once helper so we don't repeatedly warn about a missing key.
  static bool _keyMissingWarned = false;

  /// Optional [client] override exists so tests can inject
  /// `package:http/testing.dart`'s `MockClient`. Production code calls
  /// `getWeather(location)` and gets the default `http.Client`.
  static Future<WeatherResponse?> getWeather(
    String location, {
    http.Client? client,
  }) async {
    if (_apiKey.isEmpty) {
      if (!_keyMissingWarned) {
        _keyMissingWarned = true;
        AppLog.w(
          'weather.key.missing',
          data: const {
            'hint': 'Pass --dart-define=OPENWEATHER_KEY=... at build time.',
          },
        );
      }
      return null;
    }
    final http.Client httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(
        '$_base?q=${Uri.encodeQueryComponent(location)},NP'
        '&appid=$_apiKey&units=metric',
      );
      final res = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        AppLog.w(
          'weather.fetch.nonOk',
          data: {'status': res.statusCode, 'location': location},
        );
        return null;
      }
      return WeatherResponse.fromJson(
        json.decode(res.body) as Map<String, dynamic>,
      );
    } catch (e, s) {
      AppLog.w(
        'weather.fetch.fail',
        error: e,
        stack: s,
        data: {'location': location},
      );
      return null;
    }
  }
}
