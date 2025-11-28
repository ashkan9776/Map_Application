// services/geocoding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Place {
  final String name;
  final String displayName;
  final LatLng location;

  Place({
    required this.name,
    required this.displayName,
    required this.location,
  });
}

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  static Future<List<Place>> searchPlaces(String query) async {
    final url = Uri.parse('$_baseUrl/search?format=json&q=$query&limit=5');
    
    final response = await http.get(url, headers: {
      'User-Agent': 'MyNavigationApp/1.0',
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      
      return data.map((item) => Place(
        name: item['name'] ?? item['display_name'],
        displayName: item['display_name'],
        location: LatLng(
          double.parse(item['lat']),
          double.parse(item['lon']),
        ),
      )).toList();
    } else {
      throw Exception('خطا در جستجوی مکان');
    }
  }

  static Future<String> reverseGeocode(LatLng location) async {
    final url = Uri.parse(
      '$_baseUrl/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}'
    );
    
    final response = await http.get(url, headers: {
      'User-Agent': 'MyNavigationApp/1.0',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] ?? 'مکان نامشخص';
    } else {
      throw Exception('خطا در تشخیص آدرس');
    }
  }
}