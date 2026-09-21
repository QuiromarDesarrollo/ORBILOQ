import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/kardex/presentation/kardex_page.dart';

class OrbiloqWmsApp extends StatelessWidget {
  const OrbiloqWmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORBILOQ WMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const KardexPage(),
    );
  }
}
