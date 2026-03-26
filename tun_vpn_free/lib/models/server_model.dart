class VpnServer {
  final String id;
  final String country;
  final String city;
  final String flag;
  final String protocol;
  final String configLink;
  final String? configJson;
  int ping;
  bool isFavorite;

  VpnServer({
    required this.id,
    required this.country,
    required this.city,
    required this.flag,
    required this.protocol,
    required this.configLink,
    this.configJson,
    this.ping = -1,
    this.isFavorite = false,
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      flag: json['flag'] ?? '',
      protocol: json['protocol'] ?? '',
      configLink: json['configLink'] ?? '',
      configJson: json['configJson'],
    );
  }

  String get displayName => '$flag $city, $country';

  String get pingLabel {
    if (ping == -1) return '-- ms';
    if (ping >= 9999) return 'Timeout';
    return '$ping ms';
  }

  String get pingQuality {
    if (ping == -1) return 'unknown';
    if (ping < 100) return 'excellent';
    if (ping < 200) return 'good';
    if (ping < 400) return 'fair';
    return 'poor';
  }

  VpnServer copyWith({int? ping, bool? isFavorite}) {
    return VpnServer(
      id: id,
      country: country,
      city: city,
      flag: flag,
      protocol: protocol,
      configLink: configLink,
      configJson: configJson,
      ping: ping ?? this.ping,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
