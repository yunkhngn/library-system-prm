import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:client/core/network/api_error.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/auth/data/models/user.dart';
import 'package:client/features/student/application/face_enrollment_controller.dart';
import 'package:client/features/student/data/face_enrollment_repository.dart';
import 'package:client/features/student/presentation/student_face_enrollment_screen.dart';
import 'package:client/features/student/presentation/widgets/face_capture_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const Authenticated(User(
      id: 'sv1',
      code: 'SV001',
      email: 'sv@example.com',
      fullName: 'Sinh viên',
      role: UserRole.student,
      status: 'ACTIVE',
      mustChangePassword: false,
      faceEnrolled: false,
      version: 1));
}

class _Repo implements FaceEnrollmentRepository {
  int consentCalls = 0, enrollCalls = 0;
  Object? failure;
  Completer<FaceEnrollment>? pending;
  FaceEnrollment current =
      const FaceEnrollment(isEnrolled: false, version: 4, imageCount: 0);
  @override
  Future<FacePolicy> policy() async => const FacePolicy(
      version: 'v1',
      title: 'Chính sách',
      content: 'Nội dung chính sách',
      minImages: 3,
      maxImages: 5,
      maxImageBytes: 5242880,
      maxTotalBytes: 26214400,
      maxPixels: 16000000);
  @override
  Future<FaceEnrollment> status() async => current;
  @override
  Future<void> consent(String policyVersion) async {
    expect(policyVersion, 'v1');
    consentCalls++;
  }

  @override
  Future<FaceEnrollment> enroll(List<FacePhoto> photos, int version) async {
    enrollCalls++;
    expect(version, 4);
    expect(photos.length, 3);
    if (failure != null) throw failure!;
    return pending == null
        ? const FaceEnrollment(isEnrolled: true, version: 5, imageCount: 3)
        : pending!.future;
  }
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late ProviderContainer container;
  late FaceEnrollmentController controller;
  setUp(() async {
    repo = _Repo();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(_Session.new),
      faceEnrollmentRepositoryProvider.overrideWithValue(repo)
    ]);
    container.listen(faceEnrollmentControllerProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    controller = container.read(faceEnrollmentControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
      'requires consent and minimum images; rejects invalid bytes and excess count',
      () async {
    final png = await _png();
    await controller.addPhotos([png]);
    expect(container.read(faceEnrollmentControllerProvider).photos, isEmpty);
    await controller.consent();
    await controller.addPhotos([
      Uint8List.fromList([1, 2, 3])
    ]);
    expect(container.read(faceEnrollmentControllerProvider).photos, isEmpty);
    await controller.addPhotos([png, png]);
    await controller.submit();
    expect(repo.enrollCalls, 0);
    await controller.addPhotos([png, png, png, png]);
    expect(container.read(faceEnrollmentControllerProvider).photos.length, 2);
    controller.removePhoto(0);
    expect(container.read(faceEnrollmentControllerProvider).photos.length, 1);
  });

  test(
      'blocks duplicate submission and clears temporary images after server success',
      () async {
    final png = await _png();
    await controller.consent();
    await controller.addPhotos([png, png, png]);
    repo.pending = Completer<FaceEnrollment>();
    final sending = controller.submit();
    await controller.submit();
    expect(repo.enrollCalls, 1);
    repo.pending!.complete(
        const FaceEnrollment(isEnrolled: true, version: 5, imageCount: 3));
    await sending;
    final state = container.read(faceEnrollmentControllerProvider);
    expect(state.success, true);
    expect(state.photos, isEmpty);
    expect(state.enrollment!.version, 5);
  });

  test('uncertain upload requires status reconciliation before retry',
      () async {
    final png = await _png();
    await controller.consent();
    await controller.addPhotos([png, png, png]);
    repo.failure = const ApiException(code: ClientErrorCode.timeout);
    await controller.submit();
    await controller.submit();
    expect(repo.enrollCalls, 1);
    expect(
        container.read(faceEnrollmentControllerProvider).needsReconcile, true);
    await controller.reconcile();
    final state = container.read(faceEnrollmentControllerProvider);
    expect(state.needsReconcile, false);
    expect(state.consented, false);
    expect(state.photos, isEmpty);
    expect(state.success, false);
  });

  test('conflict reloads version and requires renewed consent', () async {
    final png = await _png();
    await controller.consent();
    await controller.addPhotos([png, png, png]);
    repo.current =
        const FaceEnrollment(isEnrolled: true, version: 9, imageCount: 3);
    repo.failure =
        const ApiException(code: 'VERSION_CONFLICT', statusCode: 409);
    await controller.submit();
    final state = container.read(faceEnrollmentControllerProvider);
    expect(state.enrollment!.version, 9);
    expect(state.consented, false);
    expect(state.photos, isEmpty);
  });

  testWidgets('camera starts only after explicit checkbox and server consent',
      (tester) async {
    var cameras = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_Session.new),
          faceEnrollmentRepositoryProvider.overrideWithValue(repo),
          faceCameraBuilderProvider
              .overrideWithValue((context, callback, limit, enabled) {
            cameras++;
            return const Text('Camera thử nghiệm');
          })
        ],
        child: const MaterialApp(
            home: Scaffold(body: StudentFaceEnrollmentScreen()))));
    await tester.pumpAndSettle();
    expect(cameras, 0);
    await tester.ensureVisible(find.text('Bắt đầu đăng ký'));
    await tester.tap(find.text('Bắt đầu đăng ký'));
    await tester.pumpAndSettle();
    expect(repo.consentCalls, 0);
    expect(cameras, 0);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đồng ý và tiếp tục'));
    await tester.tap(find.text('Đồng ý và tiếp tục'));
    await tester.pumpAndSettle();
    expect(repo.consentCalls, 1);
    expect(cameras, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
