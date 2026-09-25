import 'package:flutter/material.dart';

/// Every parent route, including recovery, loses access when the app is hidden.
mixin ParentSessionLock<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
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
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
