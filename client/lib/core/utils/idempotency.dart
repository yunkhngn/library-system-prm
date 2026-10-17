import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One key per user-intended access action. Reuse the same key when retrying
/// or recovering an uncertain outcome; never generate a new key for a retry.
String newIdempotencyKey() => _uuid.v4();
