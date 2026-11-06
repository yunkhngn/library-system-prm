import 'package:dio/dio.dart';

class FieldError {
  const FieldError({required this.field, required this.message});

  factory FieldError.fromJson(Map<String, dynamic> json) =>
      FieldError(field: json['field'] as String, message: json['message'] as String);

  final String field;
  final String message;
}

/// Error codes produced on the client when no `ApiError` body is available.
abstract final class ClientErrorCode {
  static const network = 'NETWORK_UNAVAILABLE';
  static const timeout = 'TIMEOUT';
  static const unknown = 'UNKNOWN';
}

/// Normalized form of the backend `ApiError` schema.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.statusCode,
    this.message = '',
    this.fieldErrors = const [],
    this.traceId,
  });

  factory ApiException.fromDio(DioException e) {
    if (e.error is ApiException) return e.error! as ApiException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(code: ClientErrorCode.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(code: ClientErrorCode.network);
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['code'] is String) {
      return ApiException(
        code: data['code'] as String,
        statusCode: e.response?.statusCode,
        message: data['message'] as String? ?? '',
        fieldErrors: (data['fieldErrors'] as List<dynamic>? ?? [])
            .map((f) => FieldError.fromJson(f as Map<String, dynamic>))
            .toList(),
        traceId: data['traceId'] as String?,
      );
    }
    return ApiException(code: ClientErrorCode.unknown, statusCode: e.response?.statusCode);
  }

  final String code;
  final int? statusCode;
  final String message;
  final List<FieldError> fieldErrors;
  final String? traceId;

  /// True when the request may have reached the server but the outcome is unknown.
  bool get isOutcomeUncertain =>
      code == ClientErrorCode.network || code == ClientErrorCode.timeout;

  /// Vietnamese, user-facing message. Never show [code] directly in the UI.
  String get userMessage => _messages[code] ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';

  static const _messages = <String, String>{
    ClientErrorCode.network: 'Không có kết nối mạng. Kiểm tra kết nối và thử lại.',
    ClientErrorCode.timeout: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
    'INVALID_CREDENTIALS': 'Mã tài khoản, email hoặc mật khẩu không đúng.',
    'ACCOUNT_LOCKED': 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.',
    'RATE_LIMITED': 'Bạn đã thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.',
    'TOKEN_EXPIRED': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'TOKEN_REVOKED': 'Phiên đăng nhập đã kết thúc. Vui lòng đăng nhập lại.',
    'INVALID_REFRESH_TOKEN': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'UNAUTHENTICATED': 'Vui lòng đăng nhập để tiếp tục.',
    'FORBIDDEN': 'Bạn không có quyền thực hiện thao tác này.',
    'PASSWORD_CHANGE_REQUIRED': 'Bạn cần đổi mật khẩu trước khi tiếp tục.',
    'CURRENT_PASSWORD_INVALID': 'Mật khẩu hiện tại không đúng.',
    'PASSWORD_UNCHANGED': 'Mật khẩu mới phải khác mật khẩu hiện tại.',
    'VALIDATION_ERROR': 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
    'RESOURCE_NOT_FOUND': 'Không tìm thấy dữ liệu yêu cầu.',
    'VERSION_CONFLICT': 'Dữ liệu đã được cập nhật. Vui lòng tải lại trước khi lưu.',
    'ALREADY_INSIDE': 'Người này đang ở trong thư viện.',
    'NOT_INSIDE': 'Người này hiện không ở trong thư viện.',
    'LIBRARY_CLOSED': 'Thư viện đang ngoài giờ mở cửa — chỉ có thể ghi nhận ra.',
    'CAPACITY_REACHED': 'Thư viện đã đạt sức chứa tối đa.',
    'SUBJECT_NOT_ELIGIBLE': 'Tài khoản không khả dụng (đã khóa hoặc không tồn tại).',
    'IDEMPOTENCY_CONFLICT': 'Yêu cầu này khác với lần gửi trước. Hệ thống không tạo lượt mới.',
    'IDEMPOTENCY_KEY_REQUIRED': 'Thiếu khóa xác nhận yêu cầu. Vui lòng thử lại.',
    'INVALID_QUERY': 'Bộ lọc không hợp lệ. Vui lòng kiểm tra lại.',
    'INVALID_REQUEST': 'Yêu cầu không hợp lệ. Vui lòng kiểm tra lại.',
    'VIDEO_FORMAT_UNSUPPORTED': 'Trình duyệt hoặc thiết bị này ghi video ở định dạng chưa được hỗ trợ. Hãy dùng QR hoặc thiết bị khác.',
    'INVALID_TIME_RANGE': 'Thời gian kết thúc ca trực phải sau thời gian bắt đầu.',
    'SHIFT_CANCELLED': 'Ca trực đã bị hủy, không thể thay đổi phân công.',
    'SHIFT_OVERLAP': 'Thủ thư đã có ca trực khác trùng thời gian.',
    'ASSIGNMENT_EXISTS': 'Thủ thư này đã được phân công vào ca.',
    'STAFF_NOT_ELIGIBLE': 'Chỉ có thể phân công thủ thư đang hoạt động.',
    'REQUEST_IN_PROGRESS': 'Yêu cầu đang được xử lý. Vui lòng chờ.',
    'DB_UNAVAILABLE': 'Hệ thống đang tạm thời gián đoạn. Vui lòng thử lại sau.',
    'INTERNAL_ERROR': 'Hệ thống gặp sự cố. Vui lòng thử lại sau.',
  };
}
