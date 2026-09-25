import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local parent gate. Failed attempts and cooldown survive process restarts.
class ParentAuth {
  ParentAuth({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  factory ParentAuth.fromJson(
    Map<String, dynamic> json, {
    DateTime Function()? clock,
  }) {
    return ParentAuth(clock: clock)
      .._salt = json['salt'] as String? ?? ''
      .._pinHash = json['pinHash'] as String? ?? ''
      .._recoveryHash = json['recoveryHash'] as String? ?? ''
      .._attempts = json['attempts'] as int? ?? 0
      .._lockedUntil = DateTime.tryParse(json['lockedUntil'] as String? ?? '');
  }
  final DateTime Function() _clock;
  String _salt = '', _pinHash = '', _recoveryHash = '';
  int _attempts = 0;
  DateTime? _lockedUntil;
  bool get hasPin => _pinHash.isNotEmpty;
  bool get locked => _lockedUntil?.isAfter(_clock()) ?? false;
  int get waitSeconds =>
      locked ? _lockedUntil!.difference(_clock()).inSeconds + 1 : 0;

  String _hash(String value) {
    List<int> bytes = utf8.encode('$_salt:$value');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  String create(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain six digits');
    }
    final random = Random.secure();
    _salt = base64Encode(List.generate(24, (_) => random.nextInt(256)));
    final recovery = List.generate(
      12,
      (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[random.nextInt(32)],
    ).join();
    _pinHash = _hash(pin);
    _recoveryHash = _hash(recovery);
    _attempts = 0;
    _lockedUntil = null;
    return recovery;
  }

  bool _check(String input, String expected) {
    if (locked || expected.isEmpty) {
      return false;
    }
    if (_hash(input) == expected) {
      _attempts = 0;
      _lockedUntil = null;
      return true;
    }
    _attempts++;
    if (_attempts >= 5) {
      _lockedUntil = _clock().add(const Duration(minutes: 1));
      _attempts = 0;
    }
    return false;
  }

  bool verify(String pin) => _check(pin, _pinHash);
  bool recover(String code) => _check(
    code.toUpperCase().replaceAll(RegExp(r'[\s-]'), ''),
    _recoveryHash,
  );
  Map<String, dynamic> toJson() => {
    'salt': _salt,
    'pinHash': _pinHash,
    'recoveryHash': _recoveryHash,
    'attempts': _attempts,
    'lockedUntil': _lockedUntil?.toIso8601String(),
  };
}
