import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Search input that reports the trimmed query only after typing pauses,
/// so list screens do not send a request per keystroke.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
    this.debounce = const Duration(milliseconds: 350),
    this.width = 320,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final Duration debounce;
  final double? width;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: AppSizes.controlDesktop,
      child: TextField(
        controller: _controller,
        onChanged: _schedule,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}
