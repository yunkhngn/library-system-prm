import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/routes.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_segmented.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../access/data/manual_access_repository.dart';
import '../../../access/data/models/access_result.dart';
import '../../../access/data/models/occupant.dart';
import '../../../access/data/models/student_lookup.dart';
import '../../../access/data/models/subject.dart';
import '../../../access/data/occupancy_repository.dart';
import '../../../visitors/data/models/visitor.dart';
import '../../../visitors/data/visitors_repository.dart';
import '../../../visitors/presentation/create_visitor_dialog.dart';

enum _Kind { student, visitor }

enum _Phase { subject, action, reason, confirm, done }

/// LIB-03 — Manual entry/exit stepper. One Idempotency-Key per submit intent.
class ManualAccessScreen extends ConsumerStatefulWidget {
  const ManualAccessScreen({
    super.key,
    this.userId,
    this.visitorId,
    this.action,
    this.code,
    this.name,
  });

  final String? userId;
  final String? visitorId;
  final String? action;
  final String? code;
  final String? name;

  @override
  ConsumerState<ManualAccessScreen> createState() => _ManualAccessScreenState();
}

class _ManualAccessScreenState extends ConsumerState<ManualAccessScreen> {
  static const _uuid = Uuid();

  _Phase _phase = _Phase.subject;
  _Kind _kind = _Kind.student;
  AccessAction? _action;
  String _idempotencyKey = '';
  bool _uncertain = false;
  bool _busy = false;
  ApiException? _error;
  AccessResult? _result;

  final _code = TextEditingController();
  final _reason = TextEditingController();

  StudentLookup? _student;
  String? _studentId;
  String? _studentLabel;
  Visitor? _visitor;

  @override
  void initState() {
    super.initState();
    _reason.addListener(_onReasonChanged);
    _applyPrefill();
  }

  void _onReasonChanged() {
    if (mounted) setState(() {});
  }

  void _applyPrefill() {
    final visitorId = widget.visitorId;
    final userId = widget.userId;
    final code = widget.code;
    final name = widget.name;
    if (visitorId != null) {
      _kind = _Kind.visitor;
      _loadVisitor(visitorId, fallbackCode: code, fallbackName: name);
    } else if (userId != null) {
      _kind = _Kind.student;
      _studentId = userId;
      _studentLabel = [
        if (name != null && name.isNotEmpty) name,
        if (code != null && code.isNotEmpty) '($code)',
      ].join(' ');
      if (code != null && code.isNotEmpty) {
        _code.text = code;
        _lookupStudent(code);
      }
    }
    if (widget.action != null) {
      _action = AccessAction.parse(widget.action);
    }
    if (visitorId != null || userId != null) {
      _phase = _action == null ? _Phase.action : _Phase.reason;
    }
  }

  Future<void> _loadVisitor(String id, {String? fallbackCode, String? fallbackName}) async {
    try {
      final visitor = await ref.read(visitorsRepositoryProvider).getById(id);
      if (!mounted) return;
      setState(() => _visitor = visitor);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        if (fallbackName != null) {
          _visitor = Visitor(
            id: id,
            referenceCode: fallbackCode ?? '',
            fullName: fallbackName,
            createdBy: null,
            createdAt: DateTime.now(),
          );
        }
      });
    }
  }

  Future<void> _lookupStudent(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await ref.read(manualAccessRepositoryProvider).lookupStudent(trimmed);
      if (!mounted) return;
      setState(() {
        _student = found;
        _studentId = found.id;
        _studentLabel = '${found.fullName} (${found.code})';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _student = null;
        if (widget.userId == null) {
          _studentId = null;
          _studentLabel = null;
        }
        _error = e.code == 'RESOURCE_NOT_FOUND'
            ? const ApiException(code: 'SUBJECT_NOT_ELIGIBLE')
            : e;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _subjectId =>
      _kind == _Kind.student ? _studentId : (_visitor?.id ?? widget.visitorId);

  String get _subjectDisplay {
    if (_kind == _Kind.visitor) {
      final v = _visitor;
      if (v != null) return '${v.fullName} (${v.referenceCode})';
      if (widget.name != null) {
        return '${widget.name}${widget.code == null ? '' : ' (${widget.code})'}';
      }
      return 'Chưa chọn khách ngoài';
    }
    return _studentLabel ?? 'Chưa chọn sinh viên';
  }

  bool get _hasSubject => _subjectId != null && _subjectId!.isNotEmpty;

  void _go(_Phase phase) => setState(() {
        _phase = phase;
        if (phase != _Phase.confirm && phase != _Phase.done) {
          _error = null;
          _uncertain = false;
        }
      });

  void _reset() {
    setState(() {
      _phase = _Phase.subject;
      _kind = _Kind.student;
      _action = null;
      _idempotencyKey = '';
      _uncertain = false;
      _busy = false;
      _error = null;
      _result = null;
      _student = null;
      _studentId = null;
      _studentLabel = null;
      _visitor = null;
      _code.clear();
      _reason.clear();
    });
  }

  Future<void> _submit() async {
    final id = _subjectId;
    final action = _action;
    if (id == null || action == null || _busy) return;
    if (_idempotencyKey.isEmpty) _idempotencyKey = _uuid.v4();
    setState(() {
      _busy = true;
      _error = null;
      _uncertain = false;
    });
    try {
      final result = await ref.read(manualAccessRepositoryProvider).recordManual(
            idempotencyKey: _idempotencyKey,
            userId: _kind == _Kind.student ? id : null,
            visitorId: _kind == _Kind.visitor ? id : null,
            action: action,
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.done;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isOutcomeUncertain) {
          _uncertain = true;
        } else {
          _error = e;
          _idempotencyKey = '';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollStatus() async {
    if (_idempotencyKey.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await ref.read(manualAccessRepositoryProvider).requestStatus(_idempotencyKey);
      if (!mounted) return;
      if (status.status == AccessRequestState.inProgress) {
        setState(() => _uncertain = true);
        return;
      }
      if (status.result != null) {
        setState(() {
          _result = status.result;
          _uncertain = false;
          _phase = _Phase.done;
        });
        return;
      }
      setState(() {
        _uncertain = false;
        _error = ApiException(code: status.errorCode ?? ClientErrorCode.unknown);
        _idempotencyKey = '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isOutcomeUncertain) {
          _uncertain = true;
        } else {
          _error = e;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _reason.removeListener(_onReasonChanged);
    _code.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Ghi nhận thủ công',
      subtitle: 'Ghi nhận vào hoặc ra khi kiosk không dùng được. Một yêu cầu chỉ gửi một lần.',
      maxWidth: 720,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_phase != _Phase.done) _StepHeader(phase: _phase),
              const SizedBox(height: AppSpacing.lg),
              if (_phase == _Phase.subject) _subjectStep(),
              if (_phase == _Phase.action) _actionStep(),
              if (_phase == _Phase.reason) _reasonStep(),
              if (_phase == _Phase.confirm) _confirmStep(),
              if (_phase == _Phase.done) _doneStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Đối tượng', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        AppSegmented<_Kind>(
          segments: const [
            AppSegment(value: _Kind.student, label: 'Sinh viên', icon: Icons.school_outlined),
            AppSegment(value: _Kind.visitor, label: 'Khách ngoài', icon: Icons.badge_outlined),
          ],
          selected: _kind,
          onChanged: (kind) => setState(() {
            _kind = kind;
            _error = null;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_kind == _Kind.student) _studentPicker() else _visitorPicker(),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlert(tone: AlertTone.error, title: _error!.userMessage),
        ],
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: 'Tiếp theo',
            onPressed: _hasSubject ? () => _go(_Phase.action) : null,
          ),
        ),
      ],
    );
  }

  Widget _studentPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Mã tài khoản sinh viên',
          controller: _code,
          hint: 'VD: SV002',
          helper: 'Nhập mã tài khoản hoặc chọn từ danh sách người đang trong thư viện.',
          textInputAction: TextInputAction.search,
          onSubmitted: _lookupStudent,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Tìm sinh viên',
            icon: Icons.search,
            variant: AppButtonVariant.secondary,
            loading: _busy,
            onPressed: () => _lookupStudent(_code.text),
          ),
        ),
        if (_student != null) ...[
          const SizedBox(height: AppSpacing.md),
          _StudentCard(student: _student!),
        ] else if (_studentLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Đã chọn: $_studentLabel', style: AppTypography.label),
        ],
        const SizedBox(height: AppSpacing.md),
        _InsideStudents(
          onPick: (occupant) {
            _code.text = occupant.subject.code;
            setState(() {
              _studentId = occupant.subject.id;
              _studentLabel = '${occupant.subject.fullName} (${occupant.subject.code})';
              _student = null;
              _error = null;
            });
            _lookupStudent(occupant.subject.code);
          },
        ),
      ],
    );
  }

  Widget _visitorPicker() {
    return _VisitorPicker(
      selected: _visitor,
      onSelected: (v) => setState(() {
        _visitor = v;
        _error = null;
      }),
    );
  }

  Widget _actionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_subjectDisplay, style: AppTypography.label),
        const SizedBox(height: AppSpacing.md),
        Text('Hành động', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          selected: _action == AccessAction.checkIn,
          icon: Icons.login,
          title: 'Ghi nhận vào',
          subtitle: 'Mở phiên mới cho người này.',
          onTap: () => setState(() => _action = AccessAction.checkIn),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActionCard(
          selected: _action == AccessAction.checkOut,
          icon: Icons.logout,
          title: 'Ghi nhận ra',
          subtitle: 'Đóng phiên đang mở.',
          onTap: () => setState(() => _action = AccessAction.checkOut),
        ),
        const SizedBox(height: AppSpacing.lg),
        _NavRow(
          onBack: () => _go(_Phase.subject),
          onNext: _action == null ? null : () => _go(_Phase.reason),
        ),
      ],
    );
  }

  Widget _reasonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lý do', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Lý do ghi nhận',
          controller: _reason,
          hint: 'VD: Sinh viên quên điện thoại',
          helper: 'Bắt buộc. Tối đa 200 ký tự.',
          maxLines: 4,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        _NavRow(
          onBack: () => _go(_Phase.action),
          onNext: _reason.text.trim().isEmpty ? null : () => _go(_Phase.confirm),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final action = _action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Xác nhận', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${action?.label ?? ''} cho $_subjectDisplay',
          style: AppTypography.bodyL,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Lý do: ${_reason.text.trim()}', style: AppTypography.bodyM),
        Text('Thời điểm: ${Fmt.dateTime(DateTime.now())}', style: AppTypography.caption),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlert(tone: AlertTone.error, title: _error!.userMessage),
        ],
        if (_uncertain) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlert(
            tone: AlertTone.warning,
            title: 'Chưa xác định được kết quả',
            message:
                'Hệ thống sẽ kiểm tra lại cùng yêu cầu này, không tạo lượt mới.',
            action: AppButton(
              label: 'Kiểm tra lại',
              variant: AppButtonVariant.secondary,
              loading: _busy,
              onPressed: _pollStatus,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            AppButton(
              label: 'Quay lại',
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : () => _go(_Phase.reason),
            ),
            const Spacer(),
            AppButton(
              label: 'Xác nhận ghi nhận',
              loading: _busy && !_uncertain,
              onPressed: _uncertain ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _doneStep() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppAlert(
          tone: AlertTone.success,
          title: 'Đã ${result.action.label.toLowerCase()} cho ${result.subject.fullName} lúc ${Fmt.time(result.occurredAt)}',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(label: 'Ghi nhận lượt khác', onPressed: _reset),
            AppButton(
              label: 'Xem lịch sử',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go(Routes.accessHistory),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.phase});
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    const labels = ['Đối tượng', 'Hành động', 'Lý do', 'Xác nhận'];
    final current = phase.index;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < labels.length; i++)
          Text(
            '${i + 1}. ${labels[i]}',
            style: AppTypography.caption.copyWith(
              color: i == current ? AppColors.action : AppColors.textSecondary,
              fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.onBack, required this.onNext});
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppButton(label: 'Quay lại', variant: AppButtonVariant.secondary, onPressed: onBack),
        const Spacer(),
        AppButton(label: 'Tiếp theo', onPressed: onNext),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.infoSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: selected ? AppColors.action : AppColors.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.action : AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.label),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});
  final StudentLookup student;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.infoSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.fullName, style: AppTypography.label),
            Text(student.code, style: AppTypography.bodyM),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (student.isLocked) const StatusBadge.locked() else const StatusBadge.active(),
                if (student.isInside) const StatusBadge.inside() else const StatusBadge.outside(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final _insideStudentsPreviewProvider = FutureProvider.autoDispose<List<Occupant>>((ref) async {
  final page = await ref.watch(occupancyRepositoryProvider).listPeople(kind: SubjectKind.user, size: 8);
  return page.items;
});

class _InsideStudents extends ConsumerWidget {
  const _InsideStudents({required this.onPick});
  final ValueChanged<Occupant> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_insideStudentsPreviewProvider).asData?.value ?? const <Occupant>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đang trong thư viện', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in items)
              ActionChip(
                label: Text('${o.subject.fullName} (${o.subject.code})'),
                onPressed: () => onPick(o),
              ),
          ],
        ),
      ],
    );
  }
}

class _VisitorPicker extends ConsumerStatefulWidget {
  const _VisitorPicker({required this.selected, required this.onSelected});
  final Visitor? selected;
  final ValueChanged<Visitor> onSelected;

  @override
  ConsumerState<_VisitorPicker> createState() => _VisitorPickerState();
}

class _VisitorPickerState extends ConsumerState<_VisitorPicker> {
  final _q = TextEditingController();
  List<Visitor> _items = const [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final page = await ref.read(visitorsRepositoryProvider).list(q: q.trim(), size: 8);
      if (!mounted) return;
      setState(() => _items = page.items);
    } on ApiException {
      if (!mounted) return;
      setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showCreateVisitorDialog(context);
    if (created == null || !mounted) return;
    widget.onSelected(created);
    _search(_q.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Tìm khách ngoài',
          controller: _q,
          hint: 'Tên hoặc mã khách',
          onChanged: _onQuery,
          onSubmitted: _search,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Thêm khách ngoài mới',
            icon: Icons.person_add_outlined,
            variant: AppButtonVariant.link,
            onPressed: _create,
          ),
        ),
        if (widget.selected != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Đã chọn: ${widget.selected!.fullName} (${widget.selected!.referenceCode})',
            style: AppTypography.label,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_loading) const LinearProgressIndicator(),
        for (final v in _items)
          ListTile(
            dense: true,
            selected: widget.selected?.id == v.id,
            title: Text(v.fullName, style: AppTypography.label),
            subtitle: Text(v.referenceCode),
            onTap: () => widget.onSelected(v),
          ),
      ],
    );
  }
}
