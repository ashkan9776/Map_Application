class FavoritePlace {
  final int? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String? category;

  FavoritePlace({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.category,
  });

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

  static FavoritePlace fromMap(Map<String, dynamic> map) {
    return FavoritePlace(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      category: map['category'],
    );
  }
}
