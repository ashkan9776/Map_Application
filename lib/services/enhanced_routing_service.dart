// services/enhanced_routing_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';

class EnhancedRoutingService {
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjA5NDc3YzYzNDg1OTQzZTdhYmFmZGZkNjRjZDk0ODg3IiwiaCI6Im11cm11cjY0In0='; // API Key خودت رو اینجا بذار
  static const String _baseUrl = 'https://api.openrouteservice.org';

  // Fallback API برای حالت خطا

  static Future<RouteInfo> getRoute(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    try {
      // اول با OpenRouteService تست کن
      return await _getRouteFromORS(start, end, mode);
    } catch (e) {
      print('خطا در OpenRouteService: $e');
      try {
        // اگر خطا داد، از OSRM استفاده کن
        return await _getRouteFromOSRM(start, end, mode);
      } catch (e2) {
        print('خطا در OSRM: $e2');
        // در آخر از محاسبه ساده استفاده کن
        return _getSimpleRoute(start, end, mode);
      }
    }
  }

  // OpenRouteService API
  static Future<RouteInfo> _getRouteFromORS(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    // بررسی API Key
    if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      throw Exception('API Key تنظیم نشده است');
    }

    String profile = _getModeProfile(mode);
    final url = Uri.parse('$_baseUrl/v2/directions/$profile');

    final requestBody = {
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      'instructions': true,
      'geometry': true,
    };

    print('درخواست به: $url');
    print('محتوای درخواست: ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 15)); // Timeout اضافه کردیم

      print('Status Code: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] == null || data['routes'].isEmpty) {
          throw Exception('مسیری یافت نشد');
        }

        final route = data['routes'][0];
        final summary = route['summary'];

        if (route['geometry'] == null ||
            route['geometry']['coordinates'] == null) {
          throw Exception('اطلاعات هندسی مسیر یافت نشد');
        }

        final coordinates = (route['geometry']['coordinates'] as List)
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();

        String instructions = '';
        if (route['segments'] != null) {
          for (var segment in route['segments']) {
            if (segment['steps'] != null) {
              for (var step in segment['steps']) {
                instructions += '${step['instruction'] ?? 'ادامه دهید'}\n';
              }
            }
          }
        }

        return RouteInfo(
          coordinates: coordinates,
          distance: (summary['distance'] ?? 0) / 1000.0,
          duration: (summary['duration'] ?? 0) / 60.0,
          instructions: instructions.trim(),
          mode: mode,
        );
      } else if (response.statusCode == 401) {
        throw Exception('API Key نامعتبر است');
      } else if (response.statusCode == 403) {
        throw Exception('دسترسی مجاز نیست - API Key را بررسی کنید');
      } else if (response.statusCode == 429) {
        throw Exception('حد مجاز درخواست روزانه تمام شده');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          'خطا ${response.statusCode}: ${errorData['error']?['message'] ?? 'خطای نامشخص'}',
        );
      }
    } on SocketException {
      throw Exception('مشکل اتصال به اینترنت');
    } on HttpException {
      throw Exception('خطا در ارسال درخواست HTTP');
    } on FormatException {
      throw Exception('خطا در پردازش پاسخ سرور');
    }
  }

  // OSRM Fallback (رایگان و بدون API Key)
  static Future<RouteInfo> _getRouteFromOSRM(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    String profile = mode == TransportMode.walking ? 'foot' : 'driving';

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    print('Fallback درخواست به OSRM: $url');

    final response = await http.get(url).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception('مسیری در OSRM یافت نشد');
      }

      final route = data['routes'][0];
      final geometry = route['geometry']['coordinates'] as List;

      final coordinates = geometry
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();

      return RouteInfo(
        coordinates: coordinates,
        distance: route['distance'] / 1000.0,
        duration: route['duration'] / 60.0,
        instructions: 'مسیر محاسبه شده با OSRM',
        mode: mode,
      );
    } else {
      throw Exception('OSRM: ${response.statusCode}');
    }
  }

  // محاسبه ساده (در صورت خطای همه سرویس‌ها)
  static RouteInfo _getSimpleRoute(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) {
    const Distance distance = Distance();
    final double distanceKm = distance.as(LengthUnit.Kilometer, start, end);

    // محاسبه زمان تقریبی بر اساس نوع حمل‌ونقل
    double avgSpeed; // km/h
    switch (mode) {
      case TransportMode.driving:
        avgSpeed = 50;
        break;
      case TransportMode.walking:
        avgSpeed = 5;
        break;
      case TransportMode.cycling:
        avgSpeed = 20;
        break;
    }

    final double durationMinutes = (distanceKm / avgSpeed) * 60;

    // خط مستقیم بین دو نقطه
    final coordinates = [start, end];

    return RouteInfo(
      coordinates: coordinates,
      distance: distanceKm,
      duration: durationMinutes,
      instructions: 'مسیر خط مستقیم محاسبه شده (تقریبی)',
      mode: mode,
    );
  }

  static String _getModeProfile(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'driving-car';
      case TransportMode.walking:
        return 'foot-walking';
      case TransportMode.cycling:
        return 'cycling-regular';
    }
  }

  // تست اتصال به API
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: {'Authorization': _apiKey},
          )
          .timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // دریافت چندین مسیر
  static Future<List<RouteInfo>> getMultipleRoutes(
    LatLng start,
    LatLng end, {
    TransportMode? preferredMode,
  }) async {
    final List<RouteInfo> routes = [];

    // اولویت دادن به مد انتخاب شده
    final modes = <TransportMode>{
      if (preferredMode != null) preferredMode,
      ...TransportMode.values,
    }.toList();

    for (TransportMode mode in modes) {
      try {
        final route = await getRoute(start, end, mode);
        routes.add(route);
      } catch (e) {
        print('خطا در دریافت مسیر ${mode.toString()}: $e');
      }
    }

    if (routes.isEmpty) {
      routes.add(_getSimpleRoute(start, end, TransportMode.driving));
    }

    return routes;
  }
}
