class WeatherResponse {
  final double temp;
  final String description;
  final String icon;
  final String name;

  WeatherResponse({
    required this.temp,
    required this.description,
    required this.icon,
    required this.name,
  });

  factory WeatherResponse.fromJson(Map<String, dynamic> json) {
    final main = (json['main'] as Map?) ?? {};
    final weather = ((json['weather'] as List?) ?? const []);
    final first = weather.isNotEmpty ? (weather.first as Map) : <String, dynamic>{};
    return WeatherResponse(
      temp: ((main['temp'] ?? 0) as num).toDouble(),
      description: (first['description'] ?? '') as String,
      icon: (first['icon'] ?? '') as String,
      name: (json['name'] ?? '') as String,
    );
  }
}
