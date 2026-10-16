import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_page.dart';

/// LIB-03 — Manual entry/exit.
class ManualAccessScreen extends StatelessWidget {
  const ManualAccessScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(screenId: 'LIB-03', title: 'Ghi nhận thủ công');
}
