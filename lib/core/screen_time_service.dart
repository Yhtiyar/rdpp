import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProtectionStatus {
  const ProtectionStatus({
    this.preview = false,
    this.supported = true,
    this.authorized = false,
    this.essentialsCount = 0,
    this.endsAt,
    this.transactionId,
    this.usageMinutes = 0,
  });
  factory ProtectionStatus.fromMap(Map<Object?, Object?> data) =>
      ProtectionStatus(
        supported: data['supported'] as bool? ?? true,
        authorized: data['authorized'] as bool? ?? false,
        essentialsCount: data['essentialsCount'] as int? ?? 0,
        transactionId: data['transactionId'] as String?,
        endsAt: data['endsAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (data['endsAt'] as num).toInt(),
              )
            : null,
        usageMinutes: data['usageMinutes'] as int? ?? 0,
      );
  final bool preview, supported, authorized;
  final int essentialsCount, usageMinutes;
  final DateTime? endsAt;
  final String? transactionId;
}

abstract interface class ScreenTimeService {
  Future<ProtectionStatus> status();
  Future<ProtectionStatus> authorize();
  Future<ProtectionStatus> configureEssentials(String locale);
  Future<DateTime> unlock({
    required int minutes,
    required String transactionId,
  });
}

class DeviceScreenTimeService implements ScreenTimeService {
  static const _channel = MethodChannel('littlewins/screen_time');
  bool get _preview => kIsWeb;
  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  @override
  Future<ProtectionStatus> status() async {
    if (_preview) {
      return const ProtectionStatus(preview: true, supported: false);
    }
    if (!_mobile) {
      return const ProtectionStatus(supported: false);
    }
    return ProtectionStatus.fromMap(
      await _channel.invokeMapMethod<Object?, Object?>('status') ?? {},
    );
  }

  @override
  Future<ProtectionStatus> authorize() async {
    if (_preview || !_mobile) {
      return status();
    }
    return ProtectionStatus.fromMap(
      await _channel.invokeMapMethod<Object?, Object?>('authorize') ?? {},
    );
  }

  @override
  Future<ProtectionStatus> configureEssentials(String locale) async {
    if (_preview || !_mobile) {
      return status();
    }
    return ProtectionStatus.fromMap(
      await _channel.invokeMapMethod<Object?, Object?>('configureEssentials', {
            'locale': locale,
          }) ??
          {},
    );
  }

  @override
  Future<DateTime> unlock({
    required int minutes,
    required String transactionId,
  }) async {
    if (_preview) {
      return DateTime.now().add(Duration(minutes: minutes));
    }
    if (!_mobile) {
      throw UnsupportedError('Screen Time is available on iOS and Android.');
    }
    final data = await _channel.invokeMapMethod<Object?, Object?>('unlock', {
      'minutes': minutes,
      'transactionId': transactionId,
    });
    final expiry = data?['endsAt'];
    if (expiry is! num) {
      throw StateError('The device did not confirm the time window.');
    }
    return DateTime.fromMillisecondsSinceEpoch(expiry.toInt());
  }
}
