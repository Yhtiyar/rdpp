import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'ui/theme.dart';
import 'features/app_shell.dart';

class LittlewinsApp extends StatelessWidget {
  const LittlewinsApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'littlewins',
      locale: Locale(controller.locale),
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: WinTheme.data,
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF0EAF9),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRect(child: child!),
          ),
        ),
      ),
      home: controller.onboarded
          ? AppShell(controller: controller)
          : OnboardingScreen(controller: controller),
    ),
  );
}
