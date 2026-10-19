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
      this.code,
      this.error,
      this.nextIssueAt});
  final DateTime now;
  final bool loading;
  final StudentQrToken? code;
  final String? error;
  final DateTime? nextIssueAt;

  int get remainingSeconds => code == null ? 0 : _secondsUntil(code!.expiresAt);
  int get waitSeconds => nextIssueAt == null ? 0 : _secondsUntil(nextIssueAt!);
  bool get isActive => !loading && code != null && remainingSeconds > 0;
  bool get canIssue => !loading && waitSeconds == 0;

  int _secondsUntil(DateTime deadline) {
    final milliseconds = deadline.difference(now).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }
}

final studentQrControllerProvider =
    NotifierProvider.autoDispose<StudentQrController, StudentQrState>(
        StudentQrController.new);

class StudentQrController extends AutoDisposeNotifier<StudentQrState> {
  Timer? _timer;
  int _generation = 0;
  DateTime _now() => ref.read(studentClockProvider)();

  @override
  StudentQrState build() {
    // Refreshing the JWT for the same account must not issue another QR.
    final identity = ref.watch(sessionControllerProvider.select((session) =>
        session is Authenticated && session.user.role == UserRole.student
            ? session.user.id
            : null));
    final generation = ++_generation;
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
    state = StudentQrState(
        now: _now(),
        loading: state.loading,
        code: state.code,
        error: state.error,
        nextIssueAt: state.nextIssueAt);
  }

  Future<void> issue() async {
    tick();
    if (!state.canIssue) return;
    await _issue();
  }

  Future<void> _issue() async {
    final generation = _generation;
    final requestedAt = _now();
    // Remove the old code before the network request and block duplicate taps.
    state = StudentQrState(now: requestedAt, loading: true);
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
          error: error is ApiException
              ? error.userMessage
              : 'Không tạo được mã QR. Vui lòng thử lại.',
          nextIssueAt: error is QrRateLimited
              ? _now().add(Duration(seconds: error.retryAfterSeconds))
              : null);
    }
  }
}
