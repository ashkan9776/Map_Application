import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Represents a single calculated route with its metadata.
///
/// This class is immutable. Using [Equatable] allows for value-based comparison,
/// making it easy to check if two routes are identical.
class RouteInfo extends Equatable {
  /// The list of geographic points that define the route's path.
  final List<LatLng> coordinates;

  /// The total distance of the route, in kilometers.
  final double distance;

  /// The estimated duration to travel the route, in minutes.
  final double duration;

  /// A summary of turn-by-turn instructions (can be a simple summary).
  final String instructions;

  /// The transport mode for which this route was calculated (e.g., driving, walking).
  final TransportMode mode;

  const RouteInfo({
    required this.coordinates,
    required this.distance,
    required this.duration,
    required this.instructions,
    required this.mode,
  });

  @override
  List<Object?> get props => [coordinates, distance, duration, instructions, mode];
  
  @override
  bool get stringify => true; // Optional: for easier debugging
}

/// Defines the available modes of transport for routing.
enum TransportMode { 
  /// For cars and other similar vehicles.
  driving, 
  
  /// For pedestrian routing.
  walking, 
  
  /// For bicycle routing.
  cycling 
}
