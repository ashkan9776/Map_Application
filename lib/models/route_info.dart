import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> coordinates;
  final double distance;
  final double duration;
  final String instructions;
  final TransportMode mode;

  RouteInfo({
    required this.coordinates,
    required this.distance,
    required this.duration,
    required this.instructions,
    required this.mode,
  });
}

enum TransportMode { driving, walking, cycling }
