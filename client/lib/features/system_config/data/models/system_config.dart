/// Backend `OpeningSlot`: `dayOfWeek` is ISO-8601 (1 = Monday … 7 = Sunday),
/// times are "HH:mm" in [SystemConfig.timezone]. A day without a slot is closed.
class OpeningSlot {
  const OpeningSlot({required this.dayOfWeek, required this.opensAt, required this.closesAt});

  factory OpeningSlot.fromJson(Map<String, dynamic> json) => OpeningSlot(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        opensAt: json['opensAt'] as String,
        closesAt: json['closesAt'] as String,
      );

  final int dayOfWeek;
  final String opensAt;
  final String closesAt;

  bool get isAllDay => opensAt == '00:00' && (closesAt == '23:59' || closesAt == '24:00');
}

/// Library rules from `GET /system-config`. Face-recognition tuning fields
/// are admin-only concerns and are not mapped here.
class SystemConfig {
  const SystemConfig({
    required this.timezone,
    required this.openingHours,
    required this.maxCapacity,
    required this.nearCapacityRatio,
    required this.capacityEnforcement,
    required this.maxSessionDurationMinutes,
    required this.scanCooldownSeconds,
    required this.version,
    required this.updatedAt,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) => SystemConfig(
        timezone: json['timezone'] as String,
        openingHours: (json['openingHours'] as List<dynamic>? ?? [])
            .map((e) => OpeningSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        maxCapacity: (json['maxCapacity'] as num).toInt(),
        nearCapacityRatio: (json['nearCapacityRatio'] as num).toDouble(),
        capacityEnforcement: json['capacityEnforcement'] as bool? ?? false,
        maxSessionDurationMinutes: (json['maxSessionDurationMinutes'] as num?)?.toInt(),
        scanCooldownSeconds: (json['scanCooldownSeconds'] as num).toInt(),
        version: (json['version'] as num).toInt(),
        updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
      );

  final String timezone;
  final List<OpeningSlot> openingHours;
  final int maxCapacity;
  final double nearCapacityRatio;

  /// When true, entries are rejected once [maxCapacity] is reached.
  final bool capacityEnforcement;

  /// Null means no maximum stay.
  final int? maxSessionDurationMinutes;
  final int scanCooldownSeconds;
  final int version;
  final DateTime? updatedAt;

  int get nearCapacityThreshold => (maxCapacity * nearCapacityRatio).ceil();

  OpeningSlot? slotFor(int isoDay) {
    for (final slot in openingHours) {
      if (slot.dayOfWeek == isoDay) return slot;
    }
    return null;
  }
}
