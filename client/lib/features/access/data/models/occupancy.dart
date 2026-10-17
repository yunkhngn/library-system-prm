class Occupancy {
  const Occupancy({
    required this.count,
    required this.maxCapacity,
    required this.nearCapacity,
    required this.capacityEnforcement,
    required this.revision,
    required this.asOf,
  });

  factory Occupancy.fromJson(Map<String, dynamic> json) => Occupancy(
        count: (json['count'] as num).toInt(),
        maxCapacity: (json['maxCapacity'] as num).toInt(),
        nearCapacity: json['nearCapacity'] as bool? ?? false,
        capacityEnforcement: json['capacityEnforcement'] as bool? ?? false,
        revision: (json['revision'] as num).toInt(),
        asOf: DateTime.parse(json['asOf'] as String),
      );

  final int count;
  final int maxCapacity;
  final bool nearCapacity;
  final bool capacityEnforcement;
  final int revision;
  final DateTime asOf;

  int get remaining => (maxCapacity - count).clamp(0, maxCapacity);
  double get ratio => maxCapacity == 0 ? 0 : count / maxCapacity;
}

class OccupancyEvent {
  const OccupancyEvent({
    required this.eventId,
    required this.occurredAt,
    required this.revision,
    required this.count,
    required this.maxCapacity,
    required this.nearCapacity,
  });

  factory OccupancyEvent.fromJson(Map<String, dynamic> json) => OccupancyEvent(
        eventId: json['eventId'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        revision: (json['revision'] as num).toInt(),
        count: (json['count'] as num).toInt(),
        maxCapacity: (json['maxCapacity'] as num).toInt(),
        nearCapacity: json['nearCapacity'] as bool? ?? false,
      );

  final String eventId;
  final DateTime occurredAt;
  final int revision;
  final int count;
  final int maxCapacity;
  final bool nearCapacity;

  Occupancy toOccupancy({required bool capacityEnforcement}) => Occupancy(
        count: count,
        maxCapacity: maxCapacity,
        nearCapacity: nearCapacity,
        capacityEnforcement: capacityEnforcement,
        revision: revision,
        asOf: occurredAt,
      );
}
