// services/routing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  // API Key رایگان از openrouteservice.org بگیرید
  static const String _apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjA5NDc3YzYzNDg1OTQzZTdhYmFmZGZkNjRjZDk0ODg3IiwiaCI6Im11cm11cjY0In0=';
  static const String _baseUrl = 'https://api.openrouteservice.org';

  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('$_baseUrl/v2/directions/driving-car');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude]
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      
      return coordinates.map((coord) => 
        LatLng(coord[1].toDouble(), coord[0].toDouble())
      ).toList();
    } else {
      throw Exception('خطا در دریافت مسیر');
    }
  }

  static Future<Map<String, dynamic>> getRouteInfo(LatLng start, LatLng end) async {
    final url = Uri.parse('$_baseUrl/v2/directions/driving-car');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude]
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final route = data['routes'][0];
      final summary = route['summary'];
      
      return {
        'distance': summary['distance'] / 1000, // کیلومتر
        'duration': summary['duration'] / 60,   // دقیقه
        'coordinates': (route['geometry']['coordinates'] as List)
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList(),
      };
    } else {
      throw Exception('خطا در دریافت اطلاعات مسیر');
    }
  }
}