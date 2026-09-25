import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import 'home_screen.dart';
import 'reading/library_screen.dart';
import 'rewards/progress_content.dart';
import 'rewards/wallet_screen.dart';
import 'parent/parent_access.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.refreshProtection();
    }
  }

  int _tab = 0;
  AppController get c => widget.controller;
  void _wallet() => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => WalletScreen(controller: c)),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SceneScaffold(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _wallet,
            icon: const Icon(Icons.stars_rounded, size: 20),
            label: Text(
              '${c.reading.balance}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
          IconButton(
            tooltip: c.tr('Parents', 'Родителям'),
            onPressed: () => openParentArea(context, c),
            icon: const Icon(
              Icons.lock_rounded,
              color: WinTheme.purple,
              size: 22,
            ),
          ),
        ],
      ),
      bottom: NavigationBar(
        height: 74,
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        backgroundColor: const Color(0xFFFEFDFF),
        indicatorColor: WinTheme.lavender,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(
              Icons.home_rounded,
              color: WinTheme.purple,
            ),
            label: c.tr('Home', 'Главная'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(
              Icons.auto_stories_rounded,
              color: WinTheme.purple,
            ),
            label: c.tr('Books', 'Книги'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(
              Icons.emoji_events_rounded,
              color: WinTheme.purple,
            ),
            label: c.tr('My wins', 'Победы'),
          ),
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey(_tab),
        child: switch (_tab) {
          0 => HomeContent(
            controller: c,
            onLibrary: () => setState(() => _tab = 1),
            onWallet: _wallet,
          ),
          1 => LibraryContent(controller: c),
          _ => ProgressContent(controller: c, onWallet: _wallet),
        },
      ),
    ),
  );
}
