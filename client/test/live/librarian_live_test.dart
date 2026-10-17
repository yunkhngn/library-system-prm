// Runs against a real backend. Skipped unless enabled:
//   flutter test test/live --dart-define=LIVE_API=true
@Tags(['live'])
library;

import 'package:client/core/network/api_error.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:client/core/utils/formatters.dart';
import 'package:client/features/auth/application/session_controller.dart';
import 'package:client/features/librarian/my_shifts/data/my_shifts_repository.dart';
import 'package:client/features/system_config/data/system_config_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('LIVE_API');
const _password = String.fromEnvironment('LIVE_PASSWORD', defaultValue: 'dev_secret_password_123');

class _MemoryTokenStorage extends TokenStorage {
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('Librarian screens against live backend',
      skip: _enabled ? false : 'Enable with --dart-define=LIVE_API=true', () {
    late _MemoryTokenStorage tokens;
    late ProviderContainer container;

    Future<void> signIn(String code) async {
      tokens = _MemoryTokenStorage();
      container = ProviderContainer(overrides: [tokenStorageProvider.overrideWithValue(tokens)]);
      container.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(sessionControllerProvider.notifier)
          .login(identifier: code, password: _password);
    }

    tearDown(() async {
      if (tokens.refreshToken != null) {
        await container.read(sessionControllerProvider.notifier).logout();
      }
      container.dispose();
    });

    test('LIB-08 parses GET /system-config', () async {
      await signIn('LIB001');
      final config = await container.read(systemConfigRepositoryProvider).fetch();

      expect(config.maxCapacity, greaterThan(0));
      expect(config.openingHours.every((s) => s.dayOfWeek >= 1 && s.dayOfWeek <= 7), isTrue);
      expect(config.nearCapacityThreshold, lessThanOrEqualTo(config.maxCapacity));
    });

    test('LIB-07 lists my shifts for the current week', () async {
      await signIn('LIB001');
      final weekStart = Fmt.startOfVietnamWeek(DateTime.now());
      final shifts = await container.read(myShiftsRepositoryProvider).listMyShifts(
            from: weekStart,
            to: weekStart.add(const Duration(days: 7)),
          );

      for (final item in shifts) {
        expect(item.assignment.staff.code, 'LIB001');
        expect(item.shift.endsAt.isAfter(item.shift.startsAt), isTrue);
      }
    });

    test('LIB-07 is librarian-only', () async {
      await signIn('AD001');
      final weekStart = Fmt.startOfVietnamWeek(DateTime.now());

      await expectLater(
        container.read(myShiftsRepositoryProvider).listMyShifts(
              from: weekStart,
              to: weekStart.add(const Duration(days: 7)),
            ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });
}
