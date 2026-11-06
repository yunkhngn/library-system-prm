import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_error.dart';
import '../../access/data/models/access_result.dart';

class KioskSession {
  const KioskSession(
      {required this.name,
      required this.mode,
      required this.faceEnabled,
      this.qrTtlSeconds = 30});
  final String name, mode;
  final bool faceEnabled;
  final int qrTtlSeconds;
  bool get isExit => mode == 'EXIT';
}

class KioskChallenge {
  const KioskChallenge(
      {required this.id,
      required this.expiresAt,
      required this.instructions,
      this.maxBytes = 10485760,
      this.duration = const Duration(seconds: 3)});
  factory KioskChallenge.fromJson(Map<String, dynamic> json) {
    final rules = json['captureRules'] as Map<String, dynamic>;
    final steps = (json['instructions'] as List)
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));
    return KioskChallenge(
      id: json['challengeId'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      instructions: steps
          .map((step) => switch (step['action']) {
                'BLINK' => 'Chớp mắt',
                'TURN_LEFT' => 'Quay đầu sang trái',
                'TURN_RIGHT' => 'Quay đầu sang phải',
                _ => 'Nhìn thẳng vào camera',
              })
          .toList(),
      maxBytes: (rules['maxClipBytes'] as num).toInt(),
      duration: Duration(
          milliseconds:
              ((rules['maxClipDurationSeconds'] as num) * 1000).round()),
    );
  }
  final String id;
  final DateTime expiresAt;
  final List<String> instructions;
  final int maxBytes;
  final Duration duration;
}

abstract interface class KioskRepository {
  /// [code] is the kiosk code shown in admin (e.g. KIOSK-01).
  Future<KioskSession> connect(String code, String credential);
  Future<void> heartbeat(String cameraStatus);
  Future<KioskChallenge> challenge();
  Future<AccessResult> face(
      KioskChallenge challenge, Uint8List clip, String key);
  Future<AccessResult> qr(String token, String key);
  Future<AccessRequestStatus> status(String key);
}

/// Device authentication is isolated from the staff/student session interceptor.
class KioskApi implements KioskRepository {
  KioskApi(this.dio);
  final Dio dio;
  String? _token;
  Options _options([String? key]) => Options(headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (key != null) 'Idempotency-Key': key,
      });

  @override
  Future<KioskSession> connect(String code, String credential) async {
    _token = null;
    final login = await apiCall(
        () => dio.post<Map<String, dynamic>>('/api/v1/kiosks/token',
            data: {'kioskCode': code, 'credential': credential}),
        (json) => json);
    _token = login['accessToken'] as String;
    try {
      final config = await apiCall(
          () => dio.get<Map<String, dynamic>>('/api/v1/kiosks/me/config',
              options: _options()),
          (json) => json);
      return KioskSession(
        name: (login['kiosk'] as Map<String, dynamic>)['name'] as String,
        mode: config['mode'] as String,
        faceEnabled: config['faceEnabled'] == true,
        qrTtlSeconds: (config['qrTtlSeconds'] as num).toInt(),
      );
    } catch (_) {
      _token = null;
      rethrow;
    }
  }

  @override
  Future<void> heartbeat(String cameraStatus) => apiCall(
        () => dio.post<Map<String, dynamic>>('/api/v1/kiosks/heartbeat',
            options: _options(),
            data: {'appVersion': '0.1.0', 'cameraStatus': cameraStatus}),
        (_) {},
      );

  @override
  Future<KioskChallenge> challenge() => apiCall(
        () => dio.post<Map<String, dynamic>>('/api/v1/access/face-challenge',
            options: _options()),
        KioskChallenge.fromJson,
      );

  AccessResult _result(Map<String, dynamic> json) {
    if (json['simulated'] == true) {
      throw const ApiException(code: 'SIMULATED_RESULT_REJECTED');
    }
    return AccessResult.fromJson(json);
  }

  @override
  Future<AccessResult> face(
          KioskChallenge challenge, Uint8List clip, String key) =>
      apiCall(
        () => dio.post<Map<String, dynamic>>('/api/v1/access/face',
            options: _options(key),
            data: FormData.fromMap({
              'challengeId': challenge.id,
              'clip': MultipartFile.fromBytes(clip,
                  filename: 'capture.mp4',
                  contentType: DioMediaType('video', 'mp4')),
            })),
        _result,
      );

  @override
  Future<AccessResult> qr(String token, String key) => apiCall(
      () => dio.post<Map<String, dynamic>>('/api/v1/access/qr',
          options: _options(key), data: {'token': token}),
      _result);

  @override
  Future<AccessRequestStatus> status(String key) => apiCall(
        () => dio.get<Map<String, dynamic>>('/api/v1/access/requests/$key',
            options: _options()),
        (json) {
          final result = json['result'];
          if (result is Map<String, dynamic>) _result(result);
          return AccessRequestStatus.fromJson(json);
        },
      );
}

final kioskRepositoryProvider = Provider.autoDispose<KioskRepository>((ref) {
  final dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30)));
  ref.onDispose(() => dio.close(force: true));
  return KioskApi(dio);
});
