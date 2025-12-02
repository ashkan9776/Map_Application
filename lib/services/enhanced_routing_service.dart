// services/enhanced_routing_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';

// --- Custom Routing Exceptions ---

/// Base exception for all routing-related errors.
class RoutingException implements Exception {
  final String message;
  RoutingException(this.message);

  @override
  String toString() => message;
}

/// Thrown when no route can be found between the start and end points.
class NoRouteFoundException extends RoutingException {
  NoRouteFoundException()
      : super('هیچ مسیر معتبری بین مبدا و مقصد انتخاب شده یافت نشد.');
}

/// Thrown when there's a network connectivity issue.
class NetworkException extends RoutingException {
  NetworkException()
      : super('اتصال اینترنت برقرار نیست. لطفاً شبکه خود را بررسی کنید.');
}

/// Thrown when the API key is invalid, expired, or has hit its quota.
class ApiKeyException extends RoutingException {
  ApiKeyException({String details = 'کلید دسترسی (API Key) نامعتبر یا منقضی شده است.'})
      : super(details);
}

// --- Service Implementation ---

class EnhancedRoutingService {
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjA5NDc3YzYzNDg1OTQzZTdhYmFmZGZkNjRjZDk0ODg3IiwiaCI6Im11cm11cjY0In0=';
  static const String _orsBaseUrl = 'https://api.openrouteservice.org';
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';

  /// Fetches a single route, with a fallback mechanism from ORS to OSRM.
  /// Throws a [RoutingException] or its subclasses if no route can be found.
  static Future<RouteInfo> getRoute(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    try {
      // 1. Attempt with OpenRouteService
      return await _getRouteFromORS(start, end, mode);
    } on Exception catch (e) {
      print('ORS failed: $e. Falling back to OSRM.');
      try {
        // 2. Attempt with OSRM as a fallback
        return await _getRouteFromOSRM(start, end, mode);
      } on Exception catch (e2) {
        print('OSRM also failed: $e2. No further fallbacks.');
        // 3. If both services fail, throw the most relevant error.
        // Prefer showing a network error if it was the root cause.
        if (e is NetworkException || e2 is NetworkException) {
          throw NetworkException();
        }
        // Otherwise, throw the original error from ORS or a generic no-route error.
        if (e is NoRouteFoundException) throw e;
        throw NoRouteFoundException();
      }
    }
  }

  /// Fetches a route from the OpenRouteService API.
  static Future<RouteInfo> _getRouteFromORS(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    if (_apiKey.contains('YOUR_API_KEY') || _apiKey.isEmpty) {
      throw ApiKeyException(details: 'کلید دسترسی (API Key) برای OpenRouteService تنظیم نشده است.');
    }

    final profile = _getModeProfileORS(mode);
    final url = Uri.parse('$_orsBaseUrl/v2/directions/$profile');
    final requestBody = jsonEncode({
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      'instructions': true,
      'geometry_format': 'geojson', // More standard format
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          throw NoRouteFoundException();
        }

        final route = data['routes'][0];
        final summary = route['summary'];
        final coordinates = (route['geometry']['coordinates'] as List)
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();

        String instructions = (route['segments'][0]['steps'] as List)
            .map((step) => step['instruction'] as String)
            .join('\n');

        return RouteInfo(
          coordinates: coordinates,
          distance: (summary['distance'] ?? 0) / 1000.0,
          duration: (summary['duration'] ?? 0) / 60.0,
          instructions: instructions,
          mode: mode,
        );
      } else {
        // Handle specific API error codes
        switch (response.statusCode) {
          case 401:
          case 403:
            throw ApiKeyException();
          case 404:
            throw NoRouteFoundException();
          case 429:
            throw ApiKeyException(details: 'ظرفیت استفاده از سرویس مسیریابی تکمیل شده است.');
          default:
            final errorMessage = data['error']?['message'] ?? 'خطای نامشخص از سرور';
            throw RoutingException('خطا ${response.statusCode}: $errorMessage');
        }
      }
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException();
    } on HttpException {
      throw RoutingException('خطا در برقراری ارتباط با سرور.');
    } on FormatException {
      throw RoutingException('پاسخ دریافت شده از سرور فرمت معتبری ندارد.');
    }
  }

  /// Fetches a route from the public OSRM API.
  static Future<RouteInfo> _getRouteFromOSRM(
    LatLng start,
    LatLng end,
    TransportMode mode,
  ) async {
    final profile = _getModeProfileOSRM(mode);
    final url = Uri.parse(
      '$_osrmBaseUrl/route/v1/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
          throw NoRouteFoundException();
        }

        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;
        final coordinates = geometry
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();

        return RouteInfo(
          coordinates: coordinates,
          distance: (route['distance'] ?? 0) / 1000.0,
          duration: (route['duration'] ?? 0) / 60.0,
          instructions: 'مسیر محاسبه شده با OSRM',
          mode: mode,
        );
      } else {
        throw RoutingException('سرویس پشتیبان مسیریابی (OSRM) با خطا مواجه شد: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException();
    } on HttpException {
      throw RoutingException('خطا در برقراری ارتباط با سرور OSRM.');
    } on FormatException {
      throw RoutingException('پاسخ دریافت شده از سرور OSRM فرمت معتبری ندارد.');
    }
  }

  /// Fetches routes for multiple transport modes.
  /// Throws an exception if no routes can be found for any mode.
  static Future<List<RouteInfo>> getMultipleRoutes(
    LatLng start,
    LatLng end, {
    TransportMode? preferredMode,
  }) async {
    final List<RouteInfo> routes = [];
    Exception? lastError;
    
    // Create a unique list of modes, with preferred mode first.
    final modes = <TransportMode>{
      if (preferredMode != null) preferredMode,
      ...TransportMode.values,
    }.toList();

    for (final mode in modes) {
      try {
        final route = await getRoute(start, end, mode);
        // Prevent adding duplicate routes for the same mode
        if (!routes.any((r) => r.mode == mode)) {
          routes.add(route);
        }
      } on Exception catch (e) {
        print('Could not get route for ${mode.toString()}: $e');
        lastError = e;
      }
    }

    if (routes.isEmpty) {
      // If no routes were found for any mode, throw the last known error,
      // or a generic "no route found" exception.
      if (lastError != null) throw lastError;
      throw NoRouteFoundException();
    }

    return routes;
  }
  
  // --- Helper Methods ---

  static String _getModeProfileORS(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'driving-car';
      case TransportMode.walking:
        return 'foot-walking';
      case TransportMode.cycling:
        return 'cycling-regular';
    }
  }

  static String _getModeProfileOSRM(TransportMode mode) {
    switch (mode) {
      case TransportMode.walking:
        return 'foot';
      case TransportMode.cycling:
        return 'bike';
      case TransportMode.driving:
      default:
        return 'driving';
    }
  }
}
