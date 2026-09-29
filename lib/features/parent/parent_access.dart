import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/illustrated_icon.dart';
import '../../ui/theme.dart';
import '../onboarding/pin_pad.dart';
import 'parent_screen.dart';
import 'parent_session_lock.dart';

Future<void> openParentArea(BuildContext context, AppController controller) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ParentAccessScreen(controller: controller),
      ),
    );

class ParentAccessScreen extends StatefulWidget {
  const ParentAccessScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ParentAccessScreen> createState() => _ParentAccessScreenState();
}

class _ParentAccessScreenState extends State<ParentAccessScreen>
    with WidgetsBindingObserver, ParentSessionLock<ParentAccessScreen> {
  String? _error;
  bool _busy = false;
  AppController get c => widget.controller;
  Future<void> _verify(String pin) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final valid = c.auth.verify(pin);
    try {
      await c.save();
      if (!mounted) {
        return;
      }
      if (valid) {
        Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(builder: (_) => ParentScreen(controller: c)),
        );
      } else {
        setState(
          () => _error = c.auth.locked
              ? c.tr(
                  'Too many tries. Wait ${c.auth.waitSeconds} seconds.',
                  'Слишком много попыток. Подождите ${c.auth.waitSeconds} сек.',
                )
              : c.tr(
                  'That PIN isn’t right. Try again.',
                  'Неверный PIN. Попробуйте снова.',
                ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = c.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _recover() async {
    final field = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.tr('Parent recovery', 'Восстановление доступа')),
        content: TextField(
          controller: field,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: c.tr('Your recovery code', 'Ваш код восстановления'),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(c.tr('Cancel', 'Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(c.tr('Recover', 'Восстановить')),
          ),
        ],
      ),
    );
    // Dispose after the dialog route has finished animating its TextField away.
    Future<void>.delayed(const Duration(milliseconds: 400), field.dispose);
    if (code == null || !mounted) {
      return;
    }
    final valid = c.auth.recover(code);
    await c.save();
    if (!mounted) {
      return;
    }
    if (valid) {
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => ChangePinScreen(controller: c, recovering: true),
        ),
      );
    } else {
      setState(
        () => _error = c.auth.locked
            ? c.tr(
                'Please wait one minute before trying again.',
                'Подождите минуту перед новой попыткой.',
              )
            : c.tr(
                'Recovery code not recognised.',
                'Код восстановления не найден.',
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SceneScaffold(
    onBack: () => Navigator.pop(context),
    child: Column(
      children: [
        Heading(
          c.tr('Parent area', 'Для родителей'),
          large: true,
          center: true,
        ),
        gap,
        const IllustratedIcon(Illustration.lock, size: 150),
        gap,
        Text(
          c.tr('Enter your 6-digit PIN', 'Введите PIN из 6 цифр'),
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        smallGap,
        Text(
          _error ??
              c.tr(
                'A little space, just for grown-ups.',
                'Немного пространства только для взрослых.',
              ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _error == null ? WinTheme.muted : const Color(0xFFB64943),
          ),
        ),
        const SizedBox(height: 24),
        PinPad(onCompleted: _verify, enabled: !_busy),
        gap,
        TextButton(
          onPressed: _busy ? null : _recover,
          child: Text(c.tr('Forgot PIN?', 'Забыли PIN?')),
        ),
        gap,
        WinButton(
          c.tr('Back to reading', 'Вернуться к чтению'),
          secondary: true,
          icon: null,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({
    super.key,
    required this.controller,
    this.recovering = false,
  });
  final AppController controller;
  final bool recovering;
  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
    with WidgetsBindingObserver, ParentSessionLock<ChangePinScreen> {
  String? _first, _error, _recovery;
  bool _busy = false;
  AppController get c => widget.controller;
  @override
  Widget build(BuildContext context) => SceneScaffold(
    onBack: () => Navigator.pop(context),
    child: Column(
      children: [
        Heading(c.tr('A new parent PIN', 'Новый PIN родителей'), center: true),
        gap,
        const IllustratedIcon(Illustration.lock, size: 130),
        gap,
        if (_recovery != null) ...[
          Text(
            c.tr(
              'Save your new recovery code',
              'Сохраните новый код восстановления',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          gap,
          SoftPanel(
            child: SelectableText(
              _recovery!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          gap,
          Text(
            c.tr(
              'Your previous recovery code no longer works.',
              'Предыдущий код восстановления больше не действует.',
            ),
            textAlign: TextAlign.center,
          ),
          gap,
          WinButton(
            c.tr('I’ve saved it', 'Код сохранён'),
            onPressed: () => Navigator.pop(context),
            icon: Icons.check,
          ),
        ] else ...[
          Text(
            _first == null
                ? c.tr('Choose 6 digits', 'Выберите 6 цифр')
                : c.tr('Enter them once more', 'Повторите PIN'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          gap,
          if (_error != null) ...[Text(_error!), gap],
          PinPad(
            enabled: !_busy,
            onCompleted: (pin) async {
              if (_first == null) {
                setState(() => _first = pin);
                return;
              }
              if (pin != _first) {
                setState(() {
                  _first = null;
                  _error = c.tr('The PINs did not match.', 'PIN не совпадает.');
                });
                return;
              }
              setState(() => _busy = true);
              final recovery = c.auth.create(pin);
              try {
                await c.save();
                if (mounted) {
                  setState(() => _recovery = recovery);
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _error = c.error);
                }
              } finally {
                if (mounted) {
                  setState(() => _busy = false);
                }
              }
            },
          ),
        ],
      ],
    ),
  );
}
