import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/models/user.dart';
import '../data/student_qr_repository.dart';
import 'student_home_provider.dart';

class StudentQrState {
  const StudentQrState(
      {required this.now,
      this.loading = false,
      this.renewing = false,
      this.autoRenewStopped = false,
      this.code,
      this.error,
      this.nextIssueAt});
  final DateTime now;
  final bool loading;

  /// Fetching the replacement while the current code stays on screen.
  final bool renewing;
  final bool autoRenewStopped;
  final StudentQrToken? code;
  final String? error;
  final DateTime? nextIssueAt;

  int get remainingSeconds => code == null ? 0 : _secondsUntil(code!.expiresAt);
  int get waitSeconds => nextIssueAt == null ? 0 : _secondsUntil(nextIssueAt!);
  bool get isActive => !loading && code != null && remainingSeconds > 0;
  bool get canIssue => !loading && !renewing && waitSeconds == 0;

  StudentQrState copyWith(
          {DateTime? now, bool? renewing, bool? autoRenewStopped}) =>
      StudentQrState(
          now: now ?? this.now,
          loading: loading,
          renewing: renewing ?? this.renewing,
          autoRenewStopped: autoRenewStopped ?? this.autoRenewStopped,
          code: code,
          error: error,
          nextIssueAt: nextIssueAt);

  int _secondsUntil(DateTime deadline) {
    final milliseconds = deadline.difference(now).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }
}

final studentQrControllerProvider =
    NotifierProvider.autoDispose<StudentQrController, StudentQrState>(
        StudentQrController.new);

class StudentQrController extends AutoDisposeNotifier<StudentQrState> {
  /// About five minutes of unattended codes; a screen left open must not
  /// keep minting tokens forever.
  static const maxAutoRenewals = 12;

  Timer? _timer;
  int _generation = 0;
  int _autoRenewals = 0;
  bool _visible = true;
  DateTime _now() => ref.read(studentClockProvider)();

  @override
  StudentQrState build() {
    // Refreshing the JWT for the same account must not issue another QR.
    final identity = ref.watch(sessionControllerProvider.select((session) =>
        session is Authenticated && session.user.role == UserRole.student
            ? session.user.id
            : null));
    final generation = ++_generation;
    _autoRenewals = 0;
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
    });
    if (identity == null) {
      return StudentQrState(
          now: _now(), error: 'Vui lòng đăng nhập bằng tài khoản sinh viên.');
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    Future.microtask(() {
      if (_generation == generation) _issue();
    });
    return StudentQrState(now: _now(), loading: true);
  }

  /// Compare absolute timestamps, including after sleep or returning to the app.
  void tick() {
    state = state.copyWith(now: _now());
    _maybeRenew();
  }

  /// Codes are only renewed while the screen is in the foreground.
  void setVisible(bool visible) {
    _visible = visible;
    tick();
  }

  Future<void> issue() async {
    tick();
    if (!state.canIssue) return;
    _autoRenewals = 0;
    await _issue();
  }

  /// Renewal follows the server's refreshAfterSeconds; failed requests are
  /// never retried automatically.
  void _maybeRenew() {
    if (!_visible || state.code == null || state.error != null) return;
    if (!state.canIssue) return;
    if (_autoRenewals >= maxAutoRenewals) {
      if (!state.autoRenewStopped) {
        state = state.copyWith(autoRenewStopped: true);
      }
      return;
    }
    _autoRenewals++;
    _issue(renew: true);
  }

  Future<void> _issue({bool renew = false}) async {
    final generation = _generation;
    final requestedAt = _now();
    final current = renew && state.isActive ? state.code : null;
    // Remove an expired code before the request and block duplicate taps.
    state = current != null
        ? state.copyWith(renewing: true)
        : StudentQrState(now: requestedAt, loading: true);
    try {
      final code = await ref.read(studentQrRepositoryProvider).issue();
      if (_generation != generation) return;
      state = StudentQrState(
          now: _now(),
          code: code,
          nextIssueAt: requestedAt.add(
              Duration(seconds: code.refreshAfterSeconds.clamp(0, 86400))));
    } catch (error) {
      if (_generation != generation) return;
      state = StudentQrState(
          now: _now(),
          // A failed renewal leaves the still-valid code until it expires.
          code: current,
          error: error is ApiException
              ? error.userMessage
              : 'Không tạo được mã QR. Vui lòng thử lại.',
          nextIssueAt: error is QrRateLimited
              ? _now().add(Duration(seconds: error.retryAfterSeconds))
              : null);
    }
  }
}
