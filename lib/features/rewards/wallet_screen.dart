import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/sound_service.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../../ui/mimi_character.dart';
import 'reward_message.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _minutes = 15;
  Timer? _ticker;
  bool _ready = false;
  String? _error;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.refreshProtection();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _reason(String? code) => switch (code) {
    'coins' => c.tr(
      'Read a little more to earn enough coins.',
      'Прочитай ещё немного, чтобы накопить монеты.',
    ),
    'limit' => c.tr(
      'That’s more than today’s remaining allowance.',
      'Это больше оставшегося лимита на сегодня.',
    ),
    'busy' => c.tr(
      'A purchase is still being checked. Please reconnect first.',
      'Покупка ещё проверяется. Проверьте подключение.',
    ),
    'permission' => c.tr(
      'Ask a parent to connect screen-time protection first.',
      'Попроси родителей подключить защиту экранного времени.',
    ),
    'active' => c.tr(
      'Enjoy your current playtime first.',
      'Сначала используй текущее время отдыха.',
    ),
    _ => c.tr(
      'The device could not confirm your time. Please try again.',
      'Устройство не подтвердило время. Попробуй снова.',
    ),
  };
  Future<void> _redeem() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          c.tr('Ready for $_minutes minutes?', 'Готов к $_minutes минутам?'),
        ),
        content: Text(
          c.tr(
            '${_minutes * 100 ~/ 15} coins will be used. Your time starts immediately and keeps running when you leave Littlewins.',
            'Будет потрачено ${_minutes * 100 ~/ 15} монет. Время начнётся сразу и продолжится после выхода из Littlewins.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(c.tr('Not yet', 'Пока нет')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.tr('Start my time', 'Начать отдых')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    setState(() => _error = null);
    try {
      await c.redeem(_minutes);
      if (mounted) {
        setState(() => _ready = true);
        SoundService.instance.playCue(FeedbackCue.timeReady, enabled: c.sound);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _reason(e is StateError ? e.message : null));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SceneScaffold(
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Heading(
            c.wallet.remaining > Duration.zero
                ? c.tr('Your playtime is ready', 'Время для отдыха')
                : c.tr('Your wins, your time', 'Твои победы, твоё время'),
            large: true,
          ),
          gap,
          if (c.protection.preview) ...[
            SoftPanel(
              color: WinTheme.peach,
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(Icons.web_rounded, color: WinTheme.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.tr(
                        'Preview mode · Other apps are not blocked.',
                        'Предпросмотр · Другие приложения не блокируются.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            gap,
          ],
          if (c.wallet.remaining > Duration.zero) ...[
            SoftPanel(
              child: Column(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    size: 90,
                    color: WinTheme.purple,
                  ),
                  gap,
                  Heading(
                    '${c.wallet.remaining.inMinutes.toString().padLeft(2, '0')}:${(c.wallet.remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    large: true,
                    center: true,
                  ),
                  smallGap,
                  Text(c.tr('Your time to play', 'Твоё время для отдыха')),
                ],
              ),
            ),
            gap,
            SoftPanel(
              color: WinTheme.mint,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: WinTheme.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.protection.preview
                          ? c.tr(
                              'Preview timer is running',
                              'Таймер предпросмотра запущен',
                            )
                          : c.tr('Time added successfully', 'Время добавлено'),
                      style: const TextStyle(
                        color: WinTheme.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            gap,
            MiMiCharacter(
              mood: MiMiMood.proud,
              size: 200,
              reactionId: _ready ? 1 : null,
            ),
            gap,
            WinButton(
              c.tr('Back to my books', 'К моим книгам'),
              onPressed: () => Navigator.pop(context),
            ),
          ] else ...[
            SoftPanel(
              child: Row(
                children: [
                  const Art('reward_star', width: 85, height: 95),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.tr(
                            '${c.reading.balance} coins',
                            '${c.reading.balance} монет',
                          ),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        smallGap,
                        Text(
                          c.tr(
                            '100 coins = 15 minutes',
                            '100 монет = 15 минут',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            gap,
            if (reachableDurations(c).isEmpty) ...[Text(rewardMessage(c)), gap],
            ...reachableDurations(c).map((minutes) {
              final cost = minutes * 100 ~/ 15;
              final selected = minutes == _minutes;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: c.purchasing
                      ? null
                      : () => setState(() => _minutes = minutes),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: minutes == 15
                          ? WinTheme.peach
                          : minutes == 30
                          ? WinTheme.lavender
                          : const Color(0xFFECF2FF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected ? WinTheme.purple : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.tr('$minutes min', '$minutes мин'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                c.tr('$cost coins', '$cost монет'),
                                style: const TextStyle(color: WinTheme.purple),
                              ),
                              if (c.reading.balance < cost)
                                Text(
                                  c.tr(
                                    '${cost - c.reading.balance} more coins needed',
                                    'Нужно ещё ${cost - c.reading.balance} монет',
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: WinTheme.purple,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SoftPanel(
              color: WinTheme.mint,
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: WinTheme.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.tr('Today’s allowance left', 'Лимит на сегодня'),
                    ),
                  ),
                  Text(
                    c.tr(
                      '${(c.dailyLimit - c.wallet.usedToday).clamp(0, c.dailyLimit)} min',
                      '${(c.dailyLimit - c.wallet.usedToday).clamp(0, c.dailyLimit)} мин',
                    ),
                    style: const TextStyle(
                      color: WinTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            gap,
            if (c.pendingPurchase != null) ...[
              SoftPanel(
                color: WinTheme.peach,
                child: Text(
                  c.tr(
                    'Your purchase is waiting for device confirmation. Your coins are reserved until we can check it.',
                    'Покупка ожидает подтверждения устройства. Монеты зарезервированы до проверки.',
                  ),
                ),
              ),
              gap,
              WinButton(
                c.tr('Check purchase status', 'Проверить покупку'),
                secondary: true,
                onPressed: () async {
                  await c.refreshProtection();
                  if (mounted) {
                    setState(() => _error = null);
                  }
                },
                icon: Icons.refresh_rounded,
              ),
              gap,
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFB64943))),
              gap,
            ],
            if (reachableDurations(c).isEmpty)
              WinButton(
                c.tr('Back to my books', 'К моим книгам'),
                onPressed: () => Navigator.pop(context),
              )
            else ...[
              WinButton(
                c.protection.preview
                    ? c.tr(
                        'Preview $_minutes minutes',
                        'Попробовать $_minutes минут',
                      )
                    : c.tr('Use $_minutes minutes', 'Получить $_minutes минут'),
                onPressed:
                    !reachableDurations(c).contains(_minutes) ||
                        c.purchasing ||
                        c.pendingPurchase != null ||
                        c.wallet.problem(
                              minutes: _minutes,
                              balance: c.reading.balance,
                              dailyLimit: c.dailyLimit,
                            ) !=
                            null
                    ? null
                    : _redeem,
                loading: c.purchasing,
              ),
              smallGap,
              Text(
                c.wallet.problem(
                          minutes: _minutes,
                          balance: c.reading.balance,
                          dailyLimit: c.dailyLimit,
                        ) !=
                        null
                    ? _reason(
                        c.wallet.problem(
                          minutes: _minutes,
                          balance: c.reading.balance,
                          dailyLimit: c.dailyLimit,
                        ),
                      )
                    : c.tr(
                        'A parent sets your daily limit.',
                        'Дневной лимит устанавливают родители.',
                      ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
