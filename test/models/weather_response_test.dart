// Per ULTIMATE.md §13 — parsing layer is where bad API payloads cause real
// crashes, so the edge cases here matter more than the happy-path one.

import 'package:flutter_test/flutter_test.dart';
import 'package:kathmanduhiker/models/weather_response.dart';

void main() {
  group('WeatherResponse.fromJson', () {
    test('parses a full OpenWeather payload', () {
      final json = {
        'main': {'temp': 18.5},
        'weather': [
          {'description': 'clear sky', 'icon': '01d'},
        ],
        'name': 'Kathmandu',
      };
      final r = WeatherResponse.fromJson(json);
      expect(r.temp, 18.5);
      expect(r.description, 'clear sky');
      expect(r.icon, '01d');
      expect(r.name, 'Kathmandu');
    });

    test('integer temperature is coerced to double', () {
      final r = WeatherResponse.fromJson({
        'main': {'temp': 20},
        'weather': [
          {'description': 'fog', 'icon': '50d'},
        ],
        'name': 'Pokhara',
      });
      expect(r.temp, 20.0);
    });

    test('missing main block returns 0.0 temp instead of crashing', () {
      final r = WeatherResponse.fromJson({
        'weather': [
          {'description': 'rain', 'icon': '10d'},
        ],
        'name': 'X',
      });
      expect(r.temp, 0.0);
    });

    test('empty weather array returns empty description and icon', () {
      final r = WeatherResponse.fromJson({
        'main': {'temp': 10},
        'weather': const <Map<String, dynamic>>[],
        'name': 'Y',
      });
      expect(r.description, '');
      expect(r.icon, '');
    });

    test('missing name field returns empty string', () {
      final r = WeatherResponse.fromJson({
        'main': {'temp': 5},
        'weather': [
          {'description': 'snow', 'icon': '13d'},
        ],
      });
      expect(r.name, '');
    });

    test('completely empty payload does not throw', () {
      expect(
        () => WeatherResponse.fromJson(const <String, dynamic>{}),
        returnsNormally,
      );
    });
  });
}
