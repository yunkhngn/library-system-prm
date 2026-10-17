import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../../../core/realtime/realtime_client.dart';
import '../data/models/occupant.dart';
import '../data/models/occupancy.dart';
import '../data/models/subject.dart';
import '../data/occupancy_repository.dart';

/// Live occupancy snapshot. Seeded from REST, then updated from `/topic/occupancy`.
class OccupancyController extends Notifier<AsyncValue<Occupancy>> {
  OccupancyController({this.connectRealtime = true});

  /// Widget tests seed occupancy over REST without opening a WebSocket.
  final bool connectRealtime;

  RealtimeClient? _client;
  VoidCallback? _unsub;
  bool _listening = false;

  @override
  AsyncValue<Occupancy> build() {
    _client = ref.read(realtimeClientProvider);
    ref.onDispose(_detach);
    Future.microtask(_bootstrap);
    return const AsyncLoading();
  }

  Future<void> reload() async {
    try {
      final snap = await ref.read(occupancyRepositoryProvider).snapshot();
      state = AsyncData(snap);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _bootstrap() async {
    await reload();
    if (!connectRealtime) return;
    final client = _client;
    if (client == null) return;
    if (!_listening) {
      client.status.addListener(_onStatus);
      _listening = true;
    }
    client.connect();
    if (client.status.value == RealtimeStatus.connected) _subscribe();
  }

  void _onStatus() {
    if (_client?.status.value == RealtimeStatus.connected) _subscribe();
  }

  void _subscribe() {
    final client = _client;
    if (client == null) return;
    _unsub?.call();
    try {
      _unsub = client.subscribeJson('/topic/occupancy', (json) {
        final event = OccupancyEvent.fromJson(json);
        final current = state.asData?.value;
        if (current != null && event.revision < current.revision) return;
        state = AsyncData(
          Occupancy(
            count: event.count,
            maxCapacity: event.maxCapacity,
            nearCapacity: event.nearCapacity,
            capacityEnforcement: current?.capacityEnforcement ?? false,
            revision: event.revision,
            asOf: event.occurredAt,
          ),
        );
      });
    } on StateError {
      // connect() has not finished yet; _onStatus will retry.
    }
  }

  void _detach() {
    _unsub?.call();
    if (_listening) {
      _client?.status.removeListener(_onStatus);
      _listening = false;
    }
  }
}

final occupancyProvider =
    NotifierProvider<OccupancyController, AsyncValue<Occupancy>>(OccupancyController.new);

class OccupantQuery {
  const OccupantQuery({this.q = '', this.kind, this.page = 0});
  final String q;
  final SubjectKind? kind;
  final int page;
}

class OccupantQueryNotifier extends Notifier<OccupantQuery> {
  @override
  OccupantQuery build() => const OccupantQuery();

  void search(String q) => state = OccupantQuery(q: q, kind: state.kind);
  void setKind(SubjectKind? kind) => state = OccupantQuery(q: state.q, kind: kind);
  void setPage(int page) => state = OccupantQuery(q: state.q, kind: state.kind, page: page);
}

final occupantQueryProvider =
    NotifierProvider<OccupantQueryNotifier, OccupantQuery>(OccupantQueryNotifier.new);

final occupantsProvider = FutureProvider.autoDispose<Paged<Occupant>>((ref) {
  ref.watch(occupancyProvider);
  final query = ref.watch(occupantQueryProvider);
  return ref.watch(occupancyRepositoryProvider).listPeople(
        q: query.q,
        kind: query.kind,
        page: query.page,
      );
});

/// Presence check that is not tied to the occupants-screen filters/page.
final subjectIsInsideProvider =
    FutureProvider.autoDispose.family<bool, ({String id, String q})>((ref, key) async {
  ref.watch(occupancyProvider);
  final page = await ref.watch(occupancyRepositoryProvider).listPeople(q: key.q, size: 20);
  return page.items.any((o) => o.subject.id == key.id);
});
