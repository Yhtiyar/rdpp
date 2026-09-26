import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../../ui/motion_spec.dart';
import 'pin_pad.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String? _firstPin, _recovery, _error;
  bool _busy = false;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (c.auth.hasPin) {
      _step = 3;
    }
  }

  void _next() => setState(() => _step++);
  @override
  Widget build(BuildContext context) => SceneScaffold(
    onBack: _step > 0 && _step < 3
        ? () => setState(() {
            _step--;
            _firstPin = null;
            _error = null;
          })
        : null,
    trailing: _step == 0
        ? TextButton(
            onPressed: () => c.setLocale(c.locale == 'en' ? 'ru' : 'en'),
            child: Text(c.locale == 'en' ? 'РУ' : 'EN'),
          )
        : Text(
            c.tr('Parent setup', 'Для родителей'),
            style: const TextStyle(fontSize: 12, color: WinTheme.muted),
          ),
    child: AnimatedSwitcher(
      duration: MotionSpec.of(context).transition,
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          0 => _welcome(),
          1 => _age(),
          2 => _pin(),
          _ => _permissions(),
        },
      ),
    ),
  );
  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Heading(
        c.tr('Little steps.\nReal growth.', 'Маленькие шаги.\nБольшой рост.'),
        large: true,
        center: true,
      ),
      gap,
      FloatArt(
        'mimi_reading',
        height:
            (MediaQuery.sizeOf(context).width.clamp(0, 480) - 44) * 327 / 381,
      ),
      gap,
      Text(
        c.tr(
          'Meet MiMi, your reading buddy.',
          'Это МиМи — твой друг по чтению.',
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      gap,
      Row(
        children:
            [
                  ('book', 'Read', 'Читай', WinTheme.peach),
                  ('star', 'Earn', 'Копи', WinTheme.mint),
                  ('growth', 'Grow', 'Расти', WinTheme.lavender),
                ]
                .map(
                  (v) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          SoftPanel(
                            color: v.$4,
                            padding: const EdgeInsets.all(10),
                            child: Art(v.$1, height: 49),
                          ),
                          smallGap,
                          Text(
                            c.tr(v.$2, v.$3),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 23),
      WinButton(
        c.tr('Set up for my child', 'Настроить для ребёнка'),
        onPressed: _next,
      ),
      TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              c.tr(
                'Reading first. Playtime after.',
                'Сначала чтение. Потом отдых.',
              ),
            ),
            content: Text(
              c.tr(
                'Read three pages, then pass a short quiz. Each verified page earns 10 coins. Exchange 100 coins for 15 minutes of screen time. Everything stays on this device.',
                'Читай по три страницы и проходи проверку. За каждую проверенную страницу — 10 монет. Обменяй 100 монет на 15 минут экранного времени. Все данные остаются на устройстве.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(c.tr('Got it', 'Понятно')),
              ),
            ],
          ),
        ),
        child: Text(c.tr('For parents', 'Для родителей')),
      ),
    ],
  );
  Widget _age() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Heading(c.tr('Choose your child’s age', 'Сколько лет ребёнку?')),
      const SizedBox(height: 25),
      ...[
        (
          4,
          '4–6',
          'Read together',
          'Читайте вместе',
          'age_young',
          WinTheme.peach,
        ),
        (
          7,
          '7–9',
          'Explore every story',
          'Открывайте истории',
          'age_middle',
          WinTheme.mint,
        ),
        (
          10,
          '10–12',
          'Think bigger',
          'Узнавайте больше',
          'age_older',
          WinTheme.lavender,
        ),
      ].map(
        (v) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            selected: c.age == v.$1,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => setState(() => c.age = v.$1),
              child: AnimatedContainer(
                duration: MotionSpec.of(context).selection,
                padding: const EdgeInsets.all(16),
                height: 153,
                decoration: BoxDecoration(
                  color: v.$6,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: c.age == v.$1 ? WinTheme.purple : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c.tr('Ages ${v.$2}', '${v.$2} лет'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          smallGap,
                          Text(c.tr(v.$3, v.$4)),
                        ],
                      ),
                    ),
                    Art(v.$5, width: 108, height: 112),
                    if (c.age == v.$1)
                      const Icon(
                        Icons.check_circle,
                        color: WinTheme.purple,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      gap,
      WinButton(c.tr('Continue', 'Продолжить'), onPressed: _next),
    ],
  );
  Widget _pin() => Column(
    children: [
      Heading(
        c.tr('Your space, protected', 'Ваше личное пространство'),
        center: true,
      ),
      gap,
      const Art('lock', height: 137),
      gap,
      Text(
        _firstPin == null
            ? c.tr('Create a 6-digit parent PIN', 'Создайте PIN из 6 цифр')
            : c.tr('Enter your PIN once more', 'Повторите PIN'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      smallGap,
      Text(
        _error ??
            c.tr('Keep this code just for you.', 'Этот код — только для вас.'),
        style: TextStyle(
          color: _error == null ? WinTheme.muted : Colors.red.shade700,
        ),
      ),
      const SizedBox(height: 22),
      PinPad(
        enabled: !_busy,
        onCompleted: (pin) async {
          if (_firstPin == null) {
            setState(() {
              _firstPin = pin;
              _error = null;
            });
            return;
          }
          if (_firstPin != pin) {
            setState(() {
              _firstPin = null;
              _error = c.tr(
                'The PINs did not match. Try again.',
                'PIN не совпадает. Попробуйте снова.',
              );
            });
            return;
          }
          setState(() => _busy = true);
          _recovery = c.auth.create(pin);
          try {
            await c.save();
            if (mounted) {
              _next();
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
      gap,
      Text(
        c.tr(
          'Your PIN protects settings and app limits.',
          'PIN защищает настройки и лимиты приложений.',
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
  Widget _permissions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Heading(
        c.tr(
          'Reading first.\nPlaytime after.',
          'Сначала чтение.\nПотом отдых.',
        ),
        large: true,
      ),
      gap,
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: const Art('screen_time', width: double.infinity),
      ),
      gap,
      Text(
        c.tr(
          'A healthy balance, one little win at a time.',
          'Здоровый баланс, шаг за шагом.',
        ),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      gap,
      _info(
        Icons.auto_stories_rounded,
        c.tr('10 pages read = 100 coins', '10 страниц = 100 монет'),
        WinTheme.lavender,
      ),
      smallGap,
      _info(
        Icons.timer_outlined,
        c.tr('100 coins = 15 minutes', '100 монет = 15 минут'),
        WinTheme.mint,
      ),
      smallGap,
      _info(
        Icons.shield_outlined,
        c.tr(
          'Parents choose the essential apps',
          'Родители выбирают важные приложения',
        ),
        WinTheme.peach,
      ),
      gap,
      if (_recovery != null) ...[
        SoftPanel(
          color: WinTheme.peach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.tr('Save your recovery code', 'Сохраните код восстановления'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              smallGap,
              SelectableText(
                _recovery!,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: WinTheme.ink,
                ),
              ),
              smallGap,
              Text(
                c.tr(
                  'Keep it somewhere your child cannot access. It resets a forgotten PIN.',
                  'Храните его в недоступном для ребёнка месте. Он поможет сбросить PIN.',
                ),
              ),
            ],
          ),
        ),
        gap,
      ],
      WinButton(
        c.tr('Let’s start reading', 'Начнём читать'),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await c.finishSetup();
                } catch (_) {
                  if (mounted) {
                    setState(() => _busy = false);
                  }
                }
              },
      ),
      smallGap,
      Text(
        c.tr(
          'Connect screen-time protection in the parent area.',
          'Подключите защиту экранного времени в разделе для родителей.',
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
  Widget _info(IconData icon, String text, Color color) => SoftPanel(
    color: color,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon, color: WinTheme.purple),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: WinTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
