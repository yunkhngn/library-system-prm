import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/models/user.dart';
import '../data/face_enrollment_repository.dart';
import 'image_dimensions.dart';
import 'student_account_provider.dart';
import 'student_home_provider.dart';

class FaceEnrollmentState {
  const FaceEnrollmentState(
      {this.policy,
      this.enrollment,
      this.loading = false,
      this.busy = false,
      this.consented = false,
      this.photos = const [],
      this.message,
      this.success = false,
      this.needsReconcile = false});
  final FacePolicy? policy;
  final FaceEnrollment? enrollment;
  final bool loading, busy, consented, success, needsReconcile;
  final List<FacePhoto> photos;
  final String? message;
  bool get canSubmit =>
      consented &&
      !busy &&
      !needsReconcile &&
      policy != null &&
      photos.length >= policy!.minImages &&
      photos.length <= policy!.maxImages;
  FaceEnrollmentState copy(
          {FacePolicy? policy,
          FaceEnrollment? enrollment,
          bool? loading,
          bool? busy,
          bool? consented,
          List<FacePhoto>? photos,
          String? message,
          bool? success,
          bool? needsReconcile}) =>
      FaceEnrollmentState(
          policy: policy ?? this.policy,
          enrollment: enrollment ?? this.enrollment,
          loading: loading ?? this.loading,
          busy: busy ?? this.busy,
          consented: consented ?? this.consented,
          photos: photos ?? this.photos,
          message: message,
          success: success ?? this.success,
          needsReconcile: needsReconcile ?? this.needsReconcile);
}

final faceEnrollmentControllerProvider =
    NotifierProvider.autoDispose<FaceEnrollmentController, FaceEnrollmentState>(
        FaceEnrollmentController.new);

class FaceEnrollmentController
    extends AutoDisposeNotifier<FaceEnrollmentState> {
  int _generation = 0;
  FaceEnrollmentRepository get _repo =>
      ref.read(faceEnrollmentRepositoryProvider);
  @override
  FaceEnrollmentState build() {
    final identity = ref.watch(sessionControllerProvider.select((s) =>
        s is Authenticated && s.user.role == UserRole.student
            ? s.user.id
            : null));
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (identity != null) {
      Future.microtask(() {
        if (generation == _generation) load();
      });
    }
    return FaceEnrollmentState(
        loading: identity != null,
        message: identity == null
            ? 'Vui lòng đăng nhập bằng tài khoản sinh viên.'
            : null);
  }

  Future<void> load() async {
    final generation = _generation;
    state = const FaceEnrollmentState(loading: true);
    try {
      final values =
          await Future.wait<Object>([_repo.policy(), _repo.status()]);
      if (generation != _generation) return;
      state = FaceEnrollmentState(
          policy: values[0] as FacePolicy,
          enrollment: values[1] as FaceEnrollment);
    } catch (error) {
      if (generation == _generation) {
        state = FaceEnrollmentState(message: _message(error));
      }
    }
  }

  Future<void> consent() async {
    if (state.busy || state.policy == null) return;
    final generation = _generation;
    state = state.copy(busy: true);
    try {
      await _repo.consent(state.policy!.version);
      if (generation == _generation) {
        state = state.copy(busy: false, consented: true);
      }
    } catch (error) {
      if (generation != _generation) return;
      if (error is ApiException && error.code == 'CONSENT_POLICY_CHANGED') {
        await load();
        if (generation != _generation) return;
      }
      state = state.copy(busy: false, message: _message(error));
    }
  }

  Future<void> addPhotos(List<Uint8List> images) async {
    if (!state.consented ||
        state.busy ||
        state.needsReconcile ||
        state.policy == null) {
      return;
    }
    final generation = _generation;
    final policy = state.policy!;
    state = state.copy(busy: true);
    try {
      if (state.photos.length + images.length > policy.maxImages) {
        throw FormatException('Chỉ chọn tối đa ${policy.maxImages} ảnh.');
      }
      final result = [...state.photos];
      for (final bytes in images) {
        if (bytes.isEmpty || bytes.length > policy.maxImageBytes) {
          throw const FormatException(
              'Mỗi ảnh phải có dung lượng không quá 5 MiB.');
        }
        final png = bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71;
        final jpeg = bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        if (!png && !jpeg) {
          throw const FormatException('Vui lòng chọn ảnh JPEG hoặc PNG.');
        }
        final dimensions = imageDimensions(bytes);
        if (dimensions.width * dimensions.height > policy.maxPixels) {
          throw const FormatException(
              'Độ phân giải ảnh vượt giới hạn cho phép.');
        }
        // ImageDescriptor.width/height throw for encoded images on Flutter web.
        // Decode only after the header dimensions pass the pixel limit.
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
        result.add(FacePhoto(
            bytes: Uint8List.fromList(bytes),
            mimeType: png ? 'image/png' : 'image/jpeg'));
      }
      if (result.fold<int>(0, (sum, photo) => sum + photo.bytes.length) >
          policy.maxTotalBytes) {
        throw const FormatException(
            'Tổng dung lượng ảnh vượt giới hạn cho phép.');
      }
      if (generation == _generation) {
        state = state.copy(busy: false, photos: List.unmodifiable(result));
      }
    } catch (error) {
      if (generation == _generation) {
        state = state.copy(
            busy: false,
            message: error is FormatException
                ? error.message.toString()
                : 'Ảnh không hợp lệ hoặc không đọc được.');
      }
    }
  }

  void removePhoto(int index) {
    if (state.busy || state.needsReconcile) return;
    state = state.copy(photos: [...state.photos]..removeAt(index));
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final generation = _generation;
    state = state.copy(busy: true);
    try {
      final result =
          await _repo.enroll(state.photos, state.enrollment!.version);
      if (generation != _generation) return;
      if (!result.isEnrolled) {
        throw const FormatException('Enrollment not confirmed');
      }
      state = state.copy(
          busy: false,
          photos: const [],
          enrollment: result,
          success: true,
          consented: false);
      ref.invalidate(studentAccountProvider);
      ref.invalidate(studentHomeProvider);
    } catch (error) {
      if (generation != _generation) return;
      final conflict = error is ApiException && error.statusCode == 409;
      if (conflict) {
        await load();
        if (generation != _generation) return;
      }
      state = state.copy(
          busy: false,
          needsReconcile: error is ApiException &&
              (error.isOutcomeUncertain || error.statusCode == 401),
          message: _message(error));
    }
  }

  Future<void> reconcile() async {
    if (state.busy) return;
    final generation = _generation;
    state = state.copy(busy: true);
    try {
      final result = await _repo.status();
      if (generation != _generation) return;
      state = state.copy(
          enrollment: result,
          busy: false,
          needsReconcile: false,
          photos: const [],
          consented: false,
          message: result.isEnrolled
              ? 'Đã đồng bộ: tài khoản đang có đăng ký khuôn mặt.'
              : 'Chưa có đăng ký khuôn mặt. Bạn có thể bắt đầu lại.');
      ref.invalidate(studentAccountProvider);
      ref.invalidate(studentHomeProvider);
    } catch (error) {
      if (generation == _generation) {
        state = state.copy(
            busy: false, needsReconcile: true, message: _message(error));
      }
    }
  }

  String _message(Object error) => error is ApiException
      ? switch (error.code) {
          'FACE_NOT_FOUND' =>
            'Không tìm thấy khuôn mặt. Hãy chụp lại ở nơi đủ sáng.',
          'MULTIPLE_FACES' => 'Mỗi ảnh chỉ được có một khuôn mặt.',
          'LOW_QUALITY' => 'Ảnh chưa đủ rõ. Vui lòng chụp lại.',
          'INCONSISTENT_FACES' => 'Các ảnh phải cùng một người.',
          'CONSENT_POLICY_CHANGED' =>
            'Chính sách đã thay đổi. Vui lòng đọc và đồng ý lại.',
          'VERSION_CONFLICT' ||
          'ENROLLMENT_CHANGED' =>
            'Đăng ký đã thay đổi. Đã tải lại trạng thái; vui lòng bắt đầu lại.',
          'CONSENT_REQUIRED' => 'Vui lòng xác nhận đồng ý trước khi đăng ký.',
          'AI_UNAVAILABLE' ||
          'MODEL_NOT_READY' ||
          'SIMULATED_RESULT_REJECTED' =>
            'Dịch vụ nhận diện chưa sẵn sàng. Bạn vẫn có thể sử dụng mã QR.',
          _ => error.isOutcomeUncertain
              ? 'Chưa xác định kết quả. Hãy kiểm tra trạng thái trước khi gửi lại.'
              : error.userMessage,
        }
      : 'Không thể hoàn tất đăng ký. Vui lòng thử lại.';
}
