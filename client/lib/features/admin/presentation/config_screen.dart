import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../access/application/occupancy_providers.dart';
import '../../system_config/application/system_config_provider.dart';
import '../../system_config/data/models/system_config.dart';
import 'widgets/admin_ui.dart';
import 'widgets/operational_config_body.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _form = GlobalKey<FormState>();
  List<OpeningSlot> _hours = [];
  final _capacity = TextEditingController();
  final _ratio = TextEditingController();
  final _cooldown = TextEditingController();
  final _model = TextEditingController();
  final _cosine = TextEditingController();
  final _gap = TextEditingController();
  final _liveness = TextEditingController();
  var _loaded = false;
  int? _loadedVersion;
  SystemConfig? _latestSavedConfig;
  var _saving = false;
  var _advanced = false;
  var _dirty = false;

  @override
  void dispose() {
    for (final controller in [
      _capacity,
      _ratio,
      _cooldown,
      _model,
      _cosine,
      _gap,
      _liveness
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller alive for the whole screen. Otherwise an action
    // started via ref.read(...notifier) may auto-dispose before its response
    // returns, even though the server has already saved the configuration.
    ref.watch(systemConfigControllerProvider);
    return PageScaffold(
      title: _advanced ? 'Cấu hình nhận diện nâng cao' : 'Cấu hình hệ thống',
      subtitle: _advanced
          ? 'Cấu hình các ngưỡng và phiên bản mô hình nhận diện'
          : 'Cấu hình quy định vận hành thư viện',
      actions: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Vận hành')),
            ButtonSegment(value: true, label: Text('Nhận diện')),
          ],
          selected: {_advanced},
          onSelectionChanged: _saving
              ? null
              : (value) => setState(() => _advanced = value.first),
        ),
      ],
      child: AsyncValueView(
        value: ref.watch(systemConfigProvider),
        onRetry: () => ref.invalidate(systemConfigProvider),
        data: (config) {
          // A FutureProvider may briefly keep its previous value while a
          // refresh is underway. Prefer the save response in that gap so a
          // stale snapshot cannot overwrite the fields the user just saved.
          final displayConfig = _latestSavedConfig != null &&
                  _latestSavedConfig!.version >= config.version
              ? _latestSavedConfig!
              : config;
          if (!_loaded ||
              (!_dirty &&
                  (_loadedVersion == null ||
                      displayConfig.version > _loadedVersion!))) {
            _load(displayConfig);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_advanced)
                  _advancedBody(displayConfig)
                else
                  AbsorbPointer(
                    absorbing: _saving,
                    child: Form(
                      key: _form,
                      child: OperationalConfigBody(
                        config: displayConfig,
                        hours: _hours,
                        capacity: _capacity,
                        ratio: _ratio,
                        cooldown: _cooldown,
                        onChanged: _markDirty,
                        onHoursChanged: (value) => setState(() {
                          _hours = value;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                AdminCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    children: [
                      Text(
                          _dirty
                              ? 'Bạn có thay đổi chưa lưu'
                              : 'Cấu hình đã được đồng bộ',
                          style: AppTypography.bodyM.copyWith(
                              color: _dirty
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                      Wrap(spacing: 10, children: [
                        OutlinedButton(
                            onPressed: _dirty && !_saving
                                ? () => setState(() {
                                      _load(displayConfig);
                                      _form.currentState?.reset();
                                    })
                                : null,
                            child: const Text('Hủy thay đổi')),
                        FilledButton(
                            onPressed: _saving || !_dirty
                                ? null
                                : () => _save(displayConfig),
                            child:
                                Text(_saving ? 'Đang lưu...' : 'Lưu cấu hình')),
                      ]),
                    ],
                  ),
                ),
              ]);
        },
      ),
    );
  }

  Widget _advancedBody(SystemConfig config) =>
      LayoutBuilder(builder: (context, constraints) {
        final formWidth = constraints.maxWidth >= 760
            ? constraints.maxWidth * .78
            : constraints.maxWidth;
        return Wrap(spacing: 24, runSpacing: 16, children: [
          SizedBox(
              width: formWidth,
              child: AdminCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFFAEB),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Cần hiệu chỉnh trên dữ liệu thực tế trước khi bật nhận diện khuôn mặt.',
                                style: AppTypography.label
                                    .copyWith(color: AppColors.warning)),
                            const SizedBox(height: 6),
                            Text(
                                'Khi chưa cấu hình mô hình, kiosk chỉ dùng Mã QR. Màn hình này không xóa mô hình đã lưu.',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textPrimary)),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    _field('Phiên bản mô hình', _model),
                    _field('Khoảng cách cosine tối đa', _cosine, numeric: true),
                    _field('Khoảng cách tối thiểu giữa hai ứng viên', _gap,
                        numeric: true),
                    _field('Điểm kiểm tra người thật tối thiểu', _liveness,
                        numeric: true),
                  ]))),
          SizedBox(
              width: constraints.maxWidth >= 760
                  ? constraints.maxWidth * .18
                  : constraints.maxWidth,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: AppColors.neutralSurface,
                    borderRadius: AppRadius.cardBorder),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhận diện khuôn mặt',
                          style: AppTypography.caption),
                      const SizedBox(height: 14),
                      Text(
                          config.faceModelVersion == null
                              ? 'Chưa cấu hình'
                              : 'Đã cấu hình',
                          style: AppTypography.label
                              .copyWith(color: AppColors.textSecondary)),
                    ]),
              )),
        ]);
      });

  Widget _field(String label, TextEditingController controller,
          {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AdminFieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            onChanged: (_) => _markDirty(),
            decoration: const InputDecoration(hintText: 'Chưa cấu hình'),
          ),
        ]),
      );

  void _load(SystemConfig config) {
    _loaded = true;
    _loadedVersion = config.version;
    _hours = List.of(config.openingHours);
    _capacity.text = '${config.maxCapacity}';
    _ratio.text = '${config.nearCapacityRatio * 100}';
    _cooldown.text = '${config.scanCooldownSeconds}';
    _model.text = config.faceModelVersion ?? '';
    _cosine.text = config.faceMaxCosineDistance?.toString() ?? '';
    _gap.text = config.faceMinDistanceGap?.toString() ?? '';
    _liveness.text = config.livenessMinScore?.toString() ?? '';
    _dirty = false;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save(SystemConfig config) async {
    if (_saving) return;
    if (!_advanced && !(_form.currentState?.validate() ?? false)) return;
    final capacity = int.tryParse(_capacity.text);
    final ratioPercent = double.tryParse(_ratio.text.replaceAll(',', '.'));
    final cooldown = int.tryParse(_cooldown.text);
    final cosine = double.tryParse(_cosine.text);
    final gap = double.tryParse(_gap.text);
    final liveness = double.tryParse(_liveness.text);
    final invalid = capacity == null ||
        capacity < 1 ||
        capacity > 100000 ||
        ratioPercent == null ||
        ratioPercent < 10 ||
        ratioPercent > 100 ||
        cooldown == null ||
        cooldown < 1 ||
        cooldown > 60 ||
        (cosine != null && (cosine < 0 || cosine > 2)) ||
        (gap != null && (gap < 0 || gap > 2)) ||
        (liveness != null && (liveness < 0 || liveness > 1));
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Giá trị không hợp lệ. Kiểm tra sức chứa, tỷ lệ, thời gian quét và các ngưỡng nhận diện.')));
      return;
    }
    if (config.faceModelVersion != null && _model.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Không thể xóa phiên bản mô hình từ màn hình này. Hãy khôi phục giá trị cũ hoặc liên hệ quản trị backend.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final updated =
          await ref.read(systemConfigControllerProvider.notifier).save({
        'version': _loadedVersion,
        if (!_advanced)
          'openingHours': [
            for (final slot in _hours)
              {
                'dayOfWeek': slot.dayOfWeek,
                'opensAt': slot.opensAt,
                'closesAt': slot.closesAt,
              },
          ],
        'maxCapacity': capacity,
        'nearCapacityRatio': ratioPercent / 100,
        'capacityEnforcement': config.capacityEnforcement,
        'scanCooldownSeconds': cooldown,
        'faceModelVersion': _emptyToNull(_model.text),
        'faceMaxCosineDistance': cosine,
        'faceMinDistanceGap': gap,
        'livenessMinScore': liveness,
      });
      ref.invalidate(occupancyProvider);
      if (mounted) {
        setState(() {
          _latestSavedConfig = updated;
          _load(updated);
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu cấu hình hệ thống.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể lưu cấu hình. Vui lòng thử lại.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
