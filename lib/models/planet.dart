class Planet {
  final String name;
  final String hostname;
  final int? discoveryYear;
  final double? orbitalPeriod;
  final double? mass;
  final double? radius;

  Planet({
    required this.name,
    required this.hostname,
    this.discoveryYear,
    this.orbitalPeriod,
    this.mass,
    this.radius,
  });

  factory Planet.fromJson(Map<String, dynamic> json) {
    return Planet(
      name: json['pl_name'] ?? 'Unknown',
      hostname: json['hostname'] ?? 'Unknown',
      discoveryYear: json['disc_year'],
      orbitalPeriod: json['pl_orbper'] != null ? double.parse(json['pl_orbper'].toString()) : null,
      mass: json['pl_bmassj'] != null ? double.parse(json['pl_bmassj'].toString()) : null,
      radius: json['pl_radj'] != null ? double.parse(json['pl_radj'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pl_name': name,
      'hostname': hostname,
      'disc_year': discoveryYear,
      'pl_orbper': orbitalPeriod,
      'pl_bmassj': mass,
      'pl_radj': radius,
    };
  }
}