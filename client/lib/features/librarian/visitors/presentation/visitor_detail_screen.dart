import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_page.dart';

/// LIB-05 — Visitor detail.
class VisitorDetailScreen extends StatelessWidget {
  const VisitorDetailScreen({super.key, required this.visitorId});

  final String visitorId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(screenId: 'LIB-05', title: 'Chi tiết khách ngoài');
}
