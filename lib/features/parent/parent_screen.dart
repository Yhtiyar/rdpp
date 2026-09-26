import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../../core/sound_service.dart';
import 'parent_access.dart';
import 'parent_session_lock.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen>
    with WidgetsBindingObserver, ParentSessionLock<ParentScreen> {
  AppController get c => widget.controller;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    c.refreshProtection();
  }

  Future<void> _connect() async {
    if (c.protection.preview) {
      setState(
        () => _message = c.tr(
          'This preview supports reading and rewards. Device protection is disabled in this build.',
          'В этом режиме доступны чтение и награды. Защита устройства отключена.',
        ),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          c.tr('Connect device protection', 'Подключить защиту устройства'),
        ),
        content: Text(
          c.tr(
            'Littlewins uses iOS Screen Time or Android Usage Access and Accessibility to recognise opened apps and block entertainment until reading time is earned. No screen contents or usage data leave this device. Essential apps remain available. You can revoke access in system settings.',
            'Littlewins использует «Экранное время» iOS или доступ к статистике и специальные возможности Android, чтобы определять запущенные приложения и ограничивать развлечения. Содержимое экрана и статистика не передаются с устройства. Важные приложения доступны всегда. Доступ можно отозвать в настройках системы.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(c.tr('Not now', 'Не сейчас')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.tr('Continue', 'Продолжить')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    await _run(() async {
      c.protection = await c.screenTime.authorize();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await c.refreshProtection();
      if (mounted) {
        setState(
          () => _message = c.protection.authorized
              ? c.tr(
                  'Device protection is connected.',
                  'Защита устройства подключена.',
                )
              : c.tr(
                  'Finish the permission steps in system settings, then check again.',
                  'Завершите настройку разрешений в системе и проверьте снова.',
                ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = c.tr(
            'Setup could not finish. Check device permissions and try again.',
            'Не удалось завершить настройку. Проверьте разрешения устройства и попробуйте снова.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SceneScaffold(
      onBack: () => Navigator.pop(context),
      trailing: Text(
        c.tr('Parent area', 'Родителям'),
        style: const TextStyle(color: WinTheme.muted, fontSize: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Heading(
            c.tr('Today’s little wins', 'Маленькие победы дня'),
            large: true,
          ),
          smallGap,
          Text(
            c.tr(
              'A clear view of their progress.',
              'Прогресс ребёнка — перед вами.',
            ),
          ),
          gap,
          SoftPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(
                  Icons.auto_stories_rounded,
                  '${c.reading.pagesOn(DateTime.now())}',
                  c.tr('pages today', 'страниц сегодня'),
                ),
                _stat(
                  Icons.stars_rounded,
                  '${c.reading.earnedCoins}',
                  c.tr('coins earned', 'монет заработано'),
                ),
                _stat(
                  Icons.timer_outlined,
                  '${c.wallet.usedToday}',
                  c.tr('minutes unlocked', 'минут куплено'),
                ),
              ],
            ),
          ),
          gap,
          Text(
            c.tr('A healthy balance', 'Здоровый баланс'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          gap,
          SoftPanel(
            color: c.protection.authorized ? WinTheme.mint : WinTheme.peach,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      c.protection.authorized
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      color: c.protection.authorized
                          ? WinTheme.green
                          : WinTheme.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.protection.preview
                            ? c.tr('Preview mode', 'Режим предпросмотра')
                            : c.protection.authorized
                            ? c.tr('Protection connected', 'Защита подключена')
                            : c.tr(
                                'Protection needs setup',
                                'Нужно настроить защиту',
                              ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                smallGap,
                Text(
                  c.protection.preview
                      ? c.tr(
                          'Reading and rewards work here. Other apps are not blocked.',
                          'Чтение и награды работают. Другие приложения не блокируются.',
                        )
                      : c.tr(
                          'Essential apps stay available. Other apps unlock with earned time.',
                          'Важные приложения доступны всегда. Остальные открываются за заработанное время.',
                        ),
                ),
                gap,
                WinButton(
                  c.protection.authorized
                      ? c.tr('Check connection', 'Проверить подключение')
                      : c.tr(
                          'Connect screen time',
                          'Подключить экранное время',
                        ),
                  onPressed: _busy ? null : _connect,
                  loading: _busy,
                  icon: Icons.shield_outlined,
                ),
                if (!c.protection.preview)
                  TextButton(
                    onPressed: _busy ? null : () => _run(c.refreshProtection),
                    child: Text(
                      c.tr(
                        'I’ve enabled permissions — check again',
                        'Разрешения включены — проверить',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          gap,
          if (_message != null) ...[
            Text(_message!, style: const TextStyle(color: WinTheme.purple)),
            gap,
          ],
          _setting(
            Icons.apps_rounded,
            c.tr('Always-available apps', 'Всегда доступные приложения'),
            c.protection.preview
                ? c.tr(
                    'Unavailable in preview mode',
                    'Недоступно в режиме предпросмотра',
                  )
                : c.tr(
                    '${c.protection.essentialsCount} selected · essential system apps stay available',
                    'Выбрано: ${c.protection.essentialsCount} · Системные функции доступны',
                  ),
            () => _run(() async {
              c.protection = await c.screenTime.configureEssentials(c.locale);
            }),
          ),
          const Divider(height: 26),
          Text(
            c.tr('Daily playtime limit', 'Дневной лимит отдыха'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          smallGap,
          DropdownButtonFormField<int>(
            initialValue: c.dailyLimit,
            decoration: InputDecoration(
              filled: true,
              fillColor: WinTheme.lavender,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: [15, 30, 45, 60, 90, 120]
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(c.tr('$m minutes', '$m минут')),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              if (v != null) {
                c.dailyLimit = v;
                await c.save();
              }
            },
          ),
          gap,
          Text(
            c.tr('Your settings', 'Ваши настройки'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          smallGap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              c.tr('Happy sounds', 'Звуки радости'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              c.tr(
                'A little celebration for every win',
                'Маленький праздник каждой победы',
              ),
            ),
            value: c.sound,
            onChanged: (v) async {
              c.sound = v;
              if (!v) SoundService.instance.silence();
              await c.save();
            },
          ),
          const Divider(),
          gap,
          Text(
            c.tr('Interface language', 'Язык интерфейса'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          smallGap,
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ru', label: Text('Русский')),
            ],
            selected: {c.locale},
            onSelectionChanged: (v) => c.setLocale(v.first),
          ),
          smallGap,
          Text(
            c.tr(
              'Stories and questions keep their original language.',
              'Книги и вопросы сохраняют язык оригинала.',
            ),
          ),
          const SizedBox(height: 24),
          _setting(
            Icons.lock_outline_rounded,
            c.tr('Change parent PIN', 'Изменить PIN родителей'),
            c.tr(
              'Keep your settings just for you',
              'Защитите доступ к настройкам',
            ),
            () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => ChangePinScreen(controller: c)),
            ),
          ),
          gap,
          SoftPanel(
            color: WinTheme.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.tr('Made for offline reading', 'Для чтения без интернета'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                smallGap,
                Text(
                  c.tr(
                    'Books, questions and progress stay on this device. No account. No ads. No server.',
                    'Книги, вопросы и прогресс хранятся на этом устройстве. Без аккаунта, рекламы и сервера.',
                  ),
                ),
              ],
            ),
          ),
          gap,
          WinButton(
            c.tr('Back to reading', 'Вернуться к чтению'),
            onPressed: () => Navigator.pop(context),
            icon: Icons.auto_stories_rounded,
          ),
        ],
      ),
    ),
  );
  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: WinTheme.purple),
        smallGap,
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: WinTheme.ink,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
  Widget _setting(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WinTheme.lavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: WinTheme.purple),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded, color: WinTheme.muted),
    onTap: action,
  );
}
