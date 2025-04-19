class SpotifyDevice {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  SpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory SpotifyDevice.fromJson(Map<String, dynamic> json) {
    return SpotifyDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}
