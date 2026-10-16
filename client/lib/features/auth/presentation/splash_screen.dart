import 'package:flutter/material.dart';

import '../../../shared/widgets/state_views.dart';

/// Shown while the stored session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: LoadingState());
}
