import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_response.dart';

class WeatherService {
  static const String _apiKey = 'e631615be1564b8422a6b695ad0cbe60';
  static const String _base = 'https://api.openweathermap.org/data/2.5/weather';

  static Future<WeatherResponse?> getWeather(String location) async {
    try {
      final uri = Uri.parse('$_base?q=$location,NP&appid=$_apiKey&units=metric');
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      return WeatherResponse.fromJson(json.decode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
