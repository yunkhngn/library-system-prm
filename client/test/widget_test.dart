import 'package:client/app/app.dart';
import 'package:client/core/storage/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyTokenStorage extends TokenStorage {
  @override
  Future<String?> readRefreshToken() async => null;
}

void main() {
  testWidgets('Without a stored session the app lands on the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(_EmptyTokenStorage())],
        child: const LibraryAccessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mã tài khoản hoặc email'), findsOneWidget);
    expect(find.text('Chưa có tài khoản hoặc quên mật khẩu? Vui lòng liên hệ quản trị viên.'), findsOneWidget);
  });
}
