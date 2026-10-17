import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../../../core/utils/formatters.dart';
import '../data/access_history_repository.dart';
import '../data/models/access_session.dart';
import '../data/models/subject.dart';

class HistoryQuery {
  HistoryQuery({
    DateTime? from,
    DateTime? to,
    this.q = '',
    this.kind,
    this.method,
    this.isOpen,
    this.visitorId,
    this.page = 0,
  })  : from = from ?? Fmt.startOfVietnamDay(DateTime.now()),
        to = to ?? Fmt.startOfNextVietnamDay(DateTime.now());

  final DateTime from;
  final DateTime to;
  final String q;
  final SubjectKind? kind;
  final AccessMethod? method;
  final bool? isOpen;
  final String? visitorId;
  final int page;

  bool get hasActiveFilters =>
      q.isNotEmpty || kind != null || method != null || isOpen != null || !_isToday;

  bool get _isToday {
    final today = Fmt.startOfVietnamDay(DateTime.now());
    return from == today && to == today.add(const Duration(days: 1));
  }

  AccessHistoryFilter toFilter() => AccessHistoryFilter(
        from: from,
        to: to,
        q: q,
        method: method,
        isOpen: isOpen,
        visitorId: visitorId,
        page: page,
      );
}

class HistoryQueryNotifier extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => HistoryQuery();

  void search(String q) => state = HistoryQuery(
        from: state.from,
        to: state.to,
        q: q,
        kind: state.kind,
        method: state.method,
        isOpen: state.isOpen,
        visitorId: state.visitorId,
      );

  void setKind(SubjectKind? kind) => state = HistoryQuery(
        from: state.from,
        to: state.to,
        q: state.q,
        kind: kind,
        method: state.method,
        isOpen: state.isOpen,
        visitorId: state.visitorId,
      );

  void setMethod(AccessMethod? method) => state = HistoryQuery(
        from: state.from,
        to: state.to,
        q: state.q,
        kind: state.kind,
        method: method,
        isOpen: state.isOpen,
        visitorId: state.visitorId,
      );

  void setOpen(bool? isOpen) => state = HistoryQuery(
        from: state.from,
        to: state.to,
        q: state.q,
        kind: state.kind,
        method: state.method,
        isOpen: isOpen,
        visitorId: state.visitorId,
      );

  void setRange(DateTime from, DateTime to) => state = HistoryQuery(
        from: from,
        to: to,
        q: state.q,
        kind: state.kind,
        method: state.method,
        isOpen: state.isOpen,
        visitorId: state.visitorId,
      );

  void setPage(int page) => state = HistoryQuery(
        from: state.from,
        to: state.to,
        q: state.q,
        kind: state.kind,
        method: state.method,
        isOpen: state.isOpen,
        visitorId: state.visitorId,
        page: page,
      );

  void clear() => state = HistoryQuery();
}

final historyQueryProvider =
    NotifierProvider<HistoryQueryNotifier, HistoryQuery>(HistoryQueryNotifier.new);

final accessHistoryProvider = FutureProvider.autoDispose<Paged<AccessSession>>((ref) {
  final query = ref.watch(historyQueryProvider);
  return ref.watch(accessHistoryRepositoryProvider).list(query.toFilter());
});

final visitorHistoryProvider =
    FutureProvider.autoDispose.family<Paged<AccessSession>, String>((ref, visitorId) {
  final now = DateTime.now().toUtc();
  return ref.watch(accessHistoryRepositoryProvider).list(
        AccessHistoryFilter(
          visitorId: visitorId,
          size: 50,
          from: now.subtract(const Duration(days: 365)),
          to: now.add(const Duration(days: 1)),
        ),
      );
});

final accessSessionProvider = FutureProvider.autoDispose.family<AccessSession, String>(
  (ref, id) => ref.watch(accessHistoryRepositoryProvider).getById(id),
);
