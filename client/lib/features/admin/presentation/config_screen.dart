import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../access/application/occupancy_providers.dart';
import '../../system_config/application/system_config_provider.dart';
import '../../system_config/data/models/system_config.dart';
import 'widgets/admin_ui.dart';
import 'widgets/operational_config_body.dart';
import 'widgets/recognition_config_body.dart';

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
          ? 'Cấu hình tùy chọn · Để trống nghĩa là kiosk chỉ dùng Mã QR'
          : 'Cấu hình quy định vận hành thư viện',
      actions: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Vận hành')),
            ButtonSegment(value: true, label: Text('Nhận diện')),
          ],
          selected: {_advanced},
          onSelectionChanged:
              _saving ? null : (value) => _switchTab(value.first),
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
                AbsorbPointer(
                  absorbing: _saving,
                  child: Form(
                    key: _form,
                    child: _advanced
                        ? RecognitionConfigBody(
                            config: displayConfig,
                            model: _model,
                            cosine: _cosine,
                            gap: _gap,
                            liveness: _liveness,
                            onChanged: _markDirty,
                          )
                        : OperationalConfigBody(
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

  void _load(SystemConfig config) {
    _loaded = true;
    _loadedVersion = config.version;
    _hours = List.of(config.openingHours);
    _capacity.text = '${config.maxCapacity}';
    _ratio.text =
        '${config.nearCapacityRatio * 100}'.replaceFirst(RegExp(r'\.0$'), '');
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

  Future<void> _switchTab(bool advanced) async {
    if (_advanced == advanced) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Bạn có thay đổi chưa lưu'),
                content: const Text(
                    'Bỏ các thay đổi hiện tại để chuyển sang cấu hình khác?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Tiếp tục chỉnh sửa')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Bỏ thay đổi')),
                ],
              ));
      if (discard != true || !mounted) return;
    }
    setState(() {
      _advanced = advanced;
      _dirty = false;
      _loaded = false;
    });
  }

  Future<void> _save(SystemConfig config) async {
    if (_saving) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final capacity = int.tryParse(_capacity.text);
    final ratioPercent = double.tryParse(_ratio.text.replaceAll(',', '.'));
    final cooldown = int.tryParse(_cooldown.text);
    final clearRecognition = [_model, _cosine, _gap, _liveness]
        .every((controller) => controller.text.trim().isEmpty);
    final patch = <String, dynamic>{
      'version': _loadedVersion,
      if (_advanced && clearRecognition) 'resetFaceConfiguration': true,
      if (_advanced && !clearRecognition) ...{
        'faceModelVersion': _model.text.trim(),
        'faceMaxCosineDistance':
            double.parse(_cosine.text.trim().replaceAll(',', '.')),
        'faceMinDistanceGap':
            double.parse(_gap.text.trim().replaceAll(',', '.')),
        'livenessMinScore':
            double.parse(_liveness.text.trim().replaceAll(',', '.')),
      },
      if (!_advanced) ...{
        'openingHours': [
          for (final slot in _hours)
            {
              'dayOfWeek': slot.dayOfWeek,
              'opensAt': slot.opensAt,
              'closesAt': slot.closesAt,
            },
        ],
        'maxCapacity': capacity,
        'nearCapacityRatio': ratioPercent! / 100,
        'scanCooldownSeconds': cooldown,
      },
    };
    setState(() => _saving = true);
    try {
      final updated =
          await ref.read(systemConfigControllerProvider.notifier).save(patch);
      if (!_advanced) ref.invalidate(occupancyProvider);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.userMessage),
          action: error.code == 'VERSION_CONFLICT'
              ? SnackBarAction(
                  label: 'Tải bản mới',
                  onPressed: () {
                    setState(() {
                      _latestSavedConfig = null;
                      _dirty = false;
                      _loaded = false;
                    });
                    ref.invalidate(systemConfigProvider);
                  },
                )
              : null,
        ));
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
}
