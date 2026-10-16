import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_page.dart';

/// LIB-02 — Current occupants.
class OccupantsScreen extends StatelessWidget {
  const OccupantsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(screenId: 'LIB-02', title: 'Người đang trong thư viện');
}
