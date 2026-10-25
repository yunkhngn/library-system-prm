import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/utils/idempotency.dart';
import '../../access/data/models/access_result.dart';
import '../data/kiosk_repository.dart';

enum KioskPhase { ready, working, success, failure }

typedef KioskCapture = Future<Uint8List> Function(KioskChallenge challenge);

class KioskController extends ChangeNotifier {
  KioskController(this.repository);
  final KioskRepository repository;
  KioskSession? session;
  KioskPhase phase = KioskPhase.ready;
  AccessResult? result;
  ApiException? error;
  String? pendingKey;
  String cameraStatus = 'UNAVAILABLE';
  bool online = false, connecting = false, _disposed = false, _pinging = false;
  Timer? _heartbeat, _returnTimer;
  bool get busy => connecting || phase == KioskPhase.working;
  bool get canScan => session != null && !busy && pendingKey == null;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> connect(String id, String credential) async {
    if (busy || pendingKey != null) return;
    connecting = true;
    error = null;
    _emit();
    try {
      final connected = await repository.connect(id.trim(), credential.trim());
      if (_disposed) return;
      session = connected;
      online = true;
      phase = KioskPhase.ready;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) => ping());
      unawaited(ping());
    } catch (e) {
      session = null;
      online = false;
      error = _asError(e);
    } finally {
      connecting = false;
      _emit();
    }
  }

  Future<void> ping() async {
    if (_pinging || session == null || _disposed) return;
    _pinging = true;
    try {
      await repository.heartbeat(cameraStatus);
      online = true;
    } catch (e) {
      online = false;
      final failure = _asError(e);
      if (_authFailure(failure)) {
        error = failure;
        if (!busy && pendingKey == null) session = null;
      }
    } finally {
      _pinging = false;
      _emit();
    }
  }

  Future<void> recognize(KioskCapture capture) => _scan((key) async {
        final challenge = await repository.challenge();
        final bytes = await capture(challenge);
        try {
          if (_disposed) throw const ApiException(code: 'CAPTURE_CANCELLED');
          if (DateTime.now().isAfter(challenge.expiresAt)) {
            throw const ApiException(code: 'CHALLENGE_EXPIRED');
          }
          if (bytes.length > challenge.maxBytes) {
            throw const ApiException(code: 'PAYLOAD_TOO_LARGE');
          }
          // The server accepts MP4. Do not relabel a WebM recording as MP4.
          if (bytes.length < 12 ||
              String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
            throw const ApiException(code: 'MP4_UNSUPPORTED');
          }
          pendingKey = key;
          return await repository.face(challenge, bytes, key);
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      });

  Future<void> scanQr(String token) => _scan((key) {
        pendingKey = key;
        return repository.qr(token.trim(), key);
      });

  Future<void> _scan(
      Future<AccessResult> Function(String key) operation) async {
    if (!canScan) return;
    phase = KioskPhase.working;
    error = null;
    result = null;
    _emit();
    try {
      _success(await operation(newIdempotencyKey()));
    } catch (e) {
      if (_disposed) return;
      error = _asError(e);
      final uncertain = error!.isOutcomeUncertain ||
          error!.code == 'REQUEST_IN_PROGRESS' ||
          (error!.statusCode ?? 0) >= 500;
      if (!uncertain) pendingKey = null;
      if (_authFailure(error!) && pendingKey == null) session = null;
      if (error!.isOutcomeUncertain) online = false;
      phase = KioskPhase.failure;
      _emit();
    }
  }

  Future<void> checkPending() async {
    if (pendingKey == null || busy) return;
    phase = KioskPhase.working;
    _emit();
    try {
      final status = await repository.status(pendingKey!);
      if (_disposed) return;
      online = true;
      if (status.status == AccessRequestState.completed) {
        pendingKey = null;
        if (status.result != null && (status.httpStatus ?? 200) < 300) {
          _success(status.result!);
          return;
        }
        error = ApiException(code: status.errorCode ?? 'UNKNOWN');
      } else {
        error = const ApiException(code: 'REQUEST_IN_PROGRESS');
      }
    } catch (e) {
      error = _asError(e);
      if (error!.statusCode == 404) {
        pendingKey = null;
        error = const ApiException(code: 'REQUEST_NOT_RECORDED');
      }
    }
    phase = KioskPhase.failure;
    _emit();
  }

  void _success(AccessResult value) {
    if (_disposed) return;
    pendingKey = null;
    result = value;
    error = null;
    online = true;
    phase = KioskPhase.success;
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 5), reset);
    _emit();
  }

  void reset() {
    if (busy || pendingKey != null || _disposed) return;
    _returnTimer?.cancel();
    result = null;
    error = null;
    phase = KioskPhase.ready;
    _emit();
  }

  bool _authFailure(ApiException e) =>
      e.statusCode == 401 ||
      ['KIOSK_REVOKED', 'TOKEN_REVOKED'].contains(e.code);
  ApiException _asError(Object e) =>
      e is ApiException ? e : const ApiException(code: 'UNKNOWN');
  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _returnTimer?.cancel();
    result = null;
    super.dispose();
  }
}

final kioskControllerProvider =
    ChangeNotifierProvider.autoDispose<KioskController>(
        (ref) => KioskController(ref.watch(kioskRepositoryProvider)));
