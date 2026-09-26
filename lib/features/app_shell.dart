import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/motion_spec.dart';
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.refreshProtection();
    }
  }

  int _tab = 0;
  final _scroll = ScrollController();
  final _offsets = <int, double>{};
  void _selectTab(int tab) {
    if (tab == _tab) return;
    _offsets[_tab] = _scroll.hasClients ? _scroll.offset : 0;
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (_offsets[tab] ?? 0).clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  AppController get c => widget.controller;
  void _wallet() => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => WalletScreen(controller: c)),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SceneScaffold(
      scrollController: _scroll,
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
        onDestinationSelected: _selectTab,
        animationDuration: MotionSpec.of(context).transition,
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
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_tab),
        tween: Tween(begin: 0, end: 1),
        duration: MotionSpec.of(context).transition,
        builder: (context, value, child) => Opacity(
          opacity: MotionSpec.of(context).reduceMotion ? 1 : value,
          child: child,
        ),
        child: switch (_tab) {
          0 => HomeContent(
            controller: c,
            onLibrary: () => _selectTab(1),
            onWallet: _wallet,
          ),
          1 => LibraryContent(controller: c),
          _ => ProgressContent(controller: c, onWallet: _wallet),
        },
      ),
    ),
  );
}
