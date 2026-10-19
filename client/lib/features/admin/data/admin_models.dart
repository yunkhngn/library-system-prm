class AdminAccount {
  const AdminAccount(
      {required this.id,
      required this.code,
      required this.email,
      required this.fullName,
      required this.role,
      required this.status,
      required this.mustChangePassword,
      required this.faceEnrolled,
      required this.version});
  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mustChangePassword: json['mustChangePassword'] == true,
      faceEnrolled: json['faceEnrolled'] == true,
      version: (json['version'] as num?)?.toInt() ?? 0);
  final String id, code, email, fullName, role, status;
  final bool mustChangePassword, faceEnrolled;
  final int version;
}

class AdminKiosk {
  const AdminKiosk(
      {required this.id,
      required this.code,
      required this.name,
      required this.mode,
      required this.status,
      required this.isOnline,
      required this.lastSeenAt,
      required this.version});
  factory AdminKiosk.fromJson(Map<String, dynamic> json) => AdminKiosk(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isOnline: json['isOnline'] == true,
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.tryParse(json['lastSeenAt'].toString()),
      version: (json['version'] as num?)?.toInt() ?? 0);
  final String id, code, name, mode, status;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int version;
}

class KioskCredential {
  const KioskCredential({required this.kiosk, required this.credential});
  factory KioskCredential.fromJson(Map<String, dynamic> json) =>
      KioskCredential(
          kiosk: AdminKiosk.fromJson(json['kiosk'] as Map<String, dynamic>),
          credential: json['credential']?.toString() ?? '');
  final AdminKiosk kiosk;
  final String credential;
}

class AdminShift {
  const AdminShift(
      {required this.id,
      required this.name,
      required this.startsAt,
      required this.endsAt,
      required this.status,
      required this.version,
      required this.assignmentCount,
      this.cancellationReason});
  factory AdminShift.fromJson(Map<String, dynamic> json) => AdminShift(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      startsAt: DateTime.parse(json['startsAt'].toString()),
      endsAt: DateTime.parse(json['endsAt'].toString()),
      status: json['status']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      assignmentCount: (json['assignmentCount'] as num?)?.toInt() ?? 0,
      cancellationReason: json['cancellationReason']?.toString());
  final String id, name, status;
  final DateTime startsAt, endsAt;
  final int version, assignmentCount;
  final String? cancellationReason;
}

class AccessBucket {
  const AccessBucket(
      {required this.startsAt,
      required this.endsAt,
      required this.checkIns,
      required this.checkOuts,
      required this.faceCheckIns,
      required this.qrCheckIns,
      required this.manualCheckIns});
  factory AccessBucket.fromJson(Map<String, dynamic> json) => AccessBucket(
      startsAt: DateTime.parse(json['startsAt'].toString()),
      endsAt: DateTime.parse(json['endsAt'].toString()),
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      checkOuts: (json['checkOuts'] as num?)?.toInt() ?? 0,
      faceCheckIns: (json['faceCheckIns'] as num?)?.toInt() ?? 0,
      qrCheckIns: (json['qrCheckIns'] as num?)?.toInt() ?? 0,
      manualCheckIns: (json['manualCheckIns'] as num?)?.toInt() ?? 0);
  final DateTime startsAt, endsAt;
  final int checkIns, checkOuts, faceCheckIns, qrCheckIns, manualCheckIns;
}

class AccessAnalytics {
  const AccessAnalytics(
      {required this.totalCheckIns,
      required this.totalCheckOuts,
      required this.averageStaySeconds,
      required this.buckets});
  factory AccessAnalytics.fromJson(Map<String, dynamic> json) =>
      AccessAnalytics(
          totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
          totalCheckOuts: (json['totalCheckOuts'] as num?)?.toInt() ?? 0,
          averageStaySeconds: (json['averageStaySeconds'] as num?)?.toDouble(),
          buckets: (json['buckets'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AccessBucket.fromJson)
              .toList(growable: false));
  final int totalCheckIns, totalCheckOuts;
  final double? averageStaySeconds;
  final List<AccessBucket> buckets;
  int get totalMethodCheckIns => buckets.fold(
      0,
      (sum, item) =>
          sum + item.faceCheckIns + item.qrCheckIns + item.manualCheckIns);
  int methodCount(String method) => buckets.fold(
      0,
      (sum, item) =>
          sum +
          switch (method) {
            'FACE' => item.faceCheckIns,
            'QR' => item.qrCheckIns,
            _ => item.manualCheckIns
          });
}

class OutcomeCount {
  const OutcomeCount({required this.outcome, required this.count});
  factory OutcomeCount.fromJson(Map<String, dynamic> json) => OutcomeCount(
      outcome: json['outcome']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0);
  final String outcome;
  final int count;
}

class RecognitionAnalytics {
  const RecognitionAnalytics(
      {required this.totalAttempts,
      required this.matched,
      required this.failed,
      required this.failureRate,
      required this.p50LatencyMs,
      required this.p95LatencyMs,
      required this.outcomes});
  factory RecognitionAnalytics.fromJson(Map<String, dynamic> json) =>
      RecognitionAnalytics(
          totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
          matched: (json['matched'] as num?)?.toInt() ?? 0,
          failed: (json['failed'] as num?)?.toInt() ?? 0,
          failureRate: (json['failureRate'] as num?)?.toDouble() ?? 0,
          p50LatencyMs: (json['p50LatencyMs'] as num?)?.toDouble(),
          p95LatencyMs: (json['p95LatencyMs'] as num?)?.toDouble(),
          outcomes: (json['outcomes'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(OutcomeCount.fromJson)
              .toList(growable: false));
  final int totalAttempts, matched, failed;
  final double failureRate;
  final double? p50LatencyMs, p95LatencyMs;
  final List<OutcomeCount> outcomes;
  int outcomeCount(String outcome) => outcomes
      .where((item) => item.outcome == outcome)
      .fold(0, (sum, item) => sum + item.count);
}
