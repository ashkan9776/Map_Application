import 'package:equatable/equatable.dart';

/// Represents a user-saved favorite location.
///
/// Using [Equatable] allows for easy value-based comparison.
class FavoritePlace extends Equatable {
  /// The unique identifier for the database entry. Can be null if not saved yet.
  final int? id;

  /// The custom name given by the user for the place (e.g., "Home", "Work").
  final String name;

  /// The formatted address of the location.
  final String address;

  /// The geographic latitude of the location.
  final double latitude;

  /// The geographic longitude of the location.
  final double longitude;

  /// The date and time when this favorite was created.
  final DateTime createdAt;

  /// A user-defined category for the place (e.g., "home", "work", "restaurant").
  final String? category;

  const FavoritePlace({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.category,
  });

  /// Creates a copy of this [FavoritePlace] but with the given fields replaced
  /// with the new values.
  FavoritePlace copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? category,
  }) {
    return FavoritePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }

  /// Converts this [FavoritePlace] instance into a [Map] for database storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'category': category,
    };
  }

  /// Creates a [FavoritePlace] instance from a [Map] retrieved from the database.
  factory FavoritePlace.fromMap(Map<String, dynamic> map) {
    return FavoritePlace(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      category: map['category'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, address, latitude, longitude, createdAt, category];
}
