import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../../../core/utils/formatters.dart';
import '../../access/application/occupancy_providers.dart';
import '../../access/data/models/occupant.dart';
import '../../access/data/occupancy_repository.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

class AdminQuery {
  const AdminQuery(
      {this.q = '',
      this.status,
      this.role,
      this.online,
      this.page = 0,
      this.size = 20});
  final String q;
  final String? status, role;
  final bool? online;
  final int page, size;
  Map<String, dynamic> get params => {
        if (q.isNotEmpty) 'q': q,
        if (status != null) 'status': status,
        if (role != null) 'role': role,
        if (online != null) 'isOnline': online,
        'page': page,
        'size': size
      };
  AdminQuery copyWith(
          {String? q,
          String? status,
          String? role,
          bool? online,
          int? page,
          int? size,
          bool clearStatus = false,
          bool clearRole = false,
          bool clearOnline = false}) =>
      AdminQuery(
          q: q ?? this.q,
          status: clearStatus ? null : status ?? this.status,
          role: clearRole ? null : role ?? this.role,
          online: clearOnline ? null : online ?? this.online,
          page: page ?? this.page,
          size: size ?? this.size);
}

class AnalyticsQuery {
  const AnalyticsQuery(
      {required this.from,
      required this.to,
      this.bucket = 'DAY',
      this.kioskId});
  final DateTime from, to;
  final String bucket;
  final String? kioskId;
  Map<String, dynamic> get params => {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (kioskId != null) 'kioskId': kioskId
      };
  Map<String, dynamic> get accessParams => {...params, 'bucket': bucket};
  AnalyticsQuery copyWith(
          {DateTime? from,
          DateTime? to,
          String? bucket,
          String? kioskId,
          bool clearKiosk = false}) =>
      AnalyticsQuery(
          from: from ?? this.from,
          to: to ?? this.to,
          bucket: bucket ?? this.bucket,
          kioskId: clearKiosk ? null : kioskId ?? this.kioskId);
}

final accountsQueryProvider =
    StateProvider.autoDispose((_) => const AdminQuery());
final kiosksQueryProvider =
    StateProvider.autoDispose((_) => const AdminQuery());
final accountsProvider = FutureProvider.autoDispose<Paged<AdminAccount>>(
    (ref) => ref
        .watch(adminRepositoryProvider)
        .listAccounts(ref.watch(accountsQueryProvider).params));
final kiosksProvider = FutureProvider.autoDispose<Paged<AdminKiosk>>((ref) =>
    ref
        .watch(adminRepositoryProvider)
        .listKiosks(ref.watch(kiosksQueryProvider).params));
final kioskDetailProvider = FutureProvider.autoDispose
    .family<AdminKiosk, String>(
        (ref, id) => ref.watch(adminRepositoryProvider).getKiosk(id));

final shiftRangeProvider = StateProvider.autoDispose<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
});
final shiftsProvider = FutureProvider.autoDispose<Paged<AdminShift>>((ref) {
  final from = ref.watch(shiftRangeProvider);
  return ref.watch(adminRepositoryProvider).listShifts({
    'from': from.toUtc().toIso8601String(),
    'to': from.add(const Duration(days: 7)).toUtc().toIso8601String(),
    'page': 0,
    'size': 100
  });
});

final analyticsQueryProvider = StateProvider.autoDispose<AnalyticsQuery>((_) {
  final now = DateTime.now();
  final to = Fmt.startOfNextVietnamDay(now);
  return AnalyticsQuery(from: to.subtract(const Duration(days: 7)), to: to);
});
final accessAnalyticsProvider = FutureProvider.autoDispose<AccessAnalytics>(
    (ref) => ref
        .watch(adminRepositoryProvider)
        .accessAnalytics(ref.watch(analyticsQueryProvider).accessParams));
final recognitionAnalyticsProvider =
    FutureProvider.autoDispose<RecognitionAnalytics>((ref) => ref
        .watch(adminRepositoryProvider)
        .recognitionAnalytics(ref.watch(analyticsQueryProvider).params));

final dashboardPeopleProvider =
    FutureProvider.autoDispose<(int, int)>((ref) async {
  ref.watch(occupancyProvider);
  final repository = ref.watch(occupancyRepositoryProvider);
  var pageIndex = 0;
  var students = 0;
  var visitors = 0;
  Paged<Occupant>? page;

  do {
    page = await repository.listPeople(page: pageIndex, size: 100);
    for (final item in page.items) {
      if (item.subject.isVisitor) {
        visitors++;
      } else {
        students++;
      }
    }
    pageIndex++;
  } while (pageIndex < page.totalPages);

  return (students, visitors);
});

final dashboardAnalyticsProvider =
    FutureProvider.autoDispose<AccessAnalytics>((ref) {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  return ref.watch(adminRepositoryProvider).accessAnalytics({
    'from': from.toUtc().toIso8601String(),
    'to': from.add(const Duration(days: 1)).toUtc().toIso8601String(),
    'bucket': 'HOUR'
  });
});

class AdminActions extends AutoDisposeAsyncNotifier<void> {
  AdminRepository get _repository => ref.read(adminRepositoryProvider);
  bool _isRunning = false;

  @override
  void build() {}

  Future<T> _run<T>(
      Future<T> Function() action, void Function() refresh) async {
    // AsyncNotifier starts as AsyncLoading while build() is being resolved.
    // That is not an in-flight admin action, so don't use state.isLoading as
    // the submission lock; otherwise the first action can fail before Dio is
    // ever called.
    if (_isRunning) {
      throw StateError('Một thao tác khác đang được xử lý.');
    }
    _isRunning = true;
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      refresh();
      return result;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  Future<AdminAccount> createAccount(Map<String, dynamic> body) => _run(
      () => _repository.createAccount(body),
      () => ref.invalidate(accountsProvider));
  Future<KioskCredential> createKiosk(Map<String, dynamic> body) => _run(
      () => _repository.createKiosk(body),
      () => ref.invalidate(kiosksProvider));
  Future<AdminKiosk> updateKiosk(String id, Map<String, dynamic> body) => _run(
      () => _repository.updateKiosk(id, body),
      () => ref.invalidate(kiosksProvider));
  Future<KioskCredential> rotateKioskCredential(String id, int version) => _run(
      () => _repository.rotateKioskCredential(id, version),
      () => ref.invalidate(kiosksProvider));
  Future<AdminShift> createShift(Map<String, dynamic> body) => _run(
      () => _repository.createShift(body),
      () => ref.invalidate(shiftsProvider));
  Future<AdminShift> cancelShift(String id, Map<String, dynamic> body) => _run(
      () => _repository.cancelShift(id, body),
      () => ref.invalidate(shiftsProvider));
}

final adminActionsProvider =
    AutoDisposeAsyncNotifierProvider<AdminActions, void>(AdminActions.new);
