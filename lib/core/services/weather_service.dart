import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final double temperature;
  final String description;
  final String icon;

  WeatherInfo({required this.temperature, required this.description, required this.icon});
}

class WeatherService {
  WeatherService._();

  /// Traduit un code météo WMO (utilisé par Open-Meteo) en description + icône simple.
  static (String, String) _describe(int code) {
    if (code == 0) return ('Ciel dégagé', '☀️');
    if (code <= 2) return ('Peu nuageux', '🌤️');
    if (code == 3) return ('Couvert', '☁️');
    if (code == 45 || code == 48) return ('Brumeux', '🌫️');
    if (code >= 51 && code <= 57) return ('Bruine', '🌦️');
    if (code >= 61 && code <= 67) return ('Pluie', '🌧️');
    if (code >= 71 && code <= 77) return ('Neige', '🌨️');
    if (code >= 80 && code <= 82) return ('Averses', '🌧️');
    if (code >= 95) return ('Orageux', '⛈️');
    return ('Variable', '🌡️');
  }

  static Future<WeatherInfo?> getWeatherForCity(String city) async {
    try {
      final geoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=fr',
      );
      final geoResponse = await http.get(geoUri).timeout(const Duration(seconds: 6));
      if (geoResponse.statusCode != 200) return null;

      final geoData = jsonDecode(geoResponse.body) as Map<String, dynamic>;
      final results = geoData['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final lat = results.first['latitude'];
      final lon = results.first['longitude'];

      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      );
      final weatherResponse = await http.get(weatherUri).timeout(const Duration(seconds: 6));
      if (weatherResponse.statusCode != 200) return null;

      final weatherData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final current = weatherData['current_weather'] as Map<String, dynamic>?;
      if (current == null) return null;

      final temp = (current['temperature'] as num).toDouble();
      final code = (current['weathercode'] as num).toInt();
      final (desc, icon) = _describe(code);

      return WeatherInfo(temperature: temp, description: desc, icon: icon);
    } catch (_) {
      return null;
    }
  }
}
