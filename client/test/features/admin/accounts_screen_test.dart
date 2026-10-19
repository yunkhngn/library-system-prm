import 'package:client/core/network/paged.dart';
import 'package:client/features/admin/application/admin_providers.dart';
import 'package:client/features/admin/data/admin_models.dart';
import 'package:client/features/admin/presentation/accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('role filter does not overflow when Administrator is selected',
      (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsQueryProvider
              .overrideWith((_) => const AdminQuery(role: 'ADMIN')),
          accountsProvider.overrideWith(
            (_) async => const Paged<AdminAccount>(
              items: [],
              page: 0,
              size: 20,
              totalElements: 0,
              totalPages: 0,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AccountsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản trị viên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
