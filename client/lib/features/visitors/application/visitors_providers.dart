import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../data/models/visitor.dart';
import '../data/visitors_repository.dart';

class VisitorQuery {
  const VisitorQuery({this.q = '', this.page = 0});
  final String q;
  final int page;
}

class VisitorQueryNotifier extends Notifier<VisitorQuery> {
  @override
  VisitorQuery build() => const VisitorQuery();

  void search(String q) => state = VisitorQuery(q: q);
  void setPage(int page) => state = VisitorQuery(q: state.q, page: page);
}

final visitorQueryProvider = NotifierProvider<VisitorQueryNotifier, VisitorQuery>(VisitorQueryNotifier.new);

final visitorsListProvider = FutureProvider.autoDispose<Paged<Visitor>>((ref) {
  final query = ref.watch(visitorQueryProvider);
  return ref.watch(visitorsRepositoryProvider).list(q: query.q, page: query.page);
});

final visitorDetailProvider = FutureProvider.autoDispose.family<Visitor, String>(
  (ref, id) => ref.watch(visitorsRepositoryProvider).getById(id),
);
