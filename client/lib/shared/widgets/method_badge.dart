import '../../features/access/data/models/subject.dart';
import 'status_badge.dart';

StatusBadge kindBadge(SubjectKind kind) => switch (kind) {
      SubjectKind.user => const StatusBadge.student(),
      SubjectKind.visitor => const StatusBadge.visitor(),
    };

StatusBadge? methodBadge(AccessMethod? method) => switch (method) {
      AccessMethod.face => const StatusBadge.face(),
      AccessMethod.qr => const StatusBadge.qr(),
      AccessMethod.manual => const StatusBadge.manual(),
      null => null,
    };
