/// Spendable balance, independent of lifetime reading and past purchases.
class RewardProgress {
  const RewardProgress._(this.coinsNeeded, this.fraction, this.affordable);
  factory RewardProgress.fromBalance(int balance) => RewardProgress._(
    (100 - balance).clamp(0, 100),
    (balance / 100).clamp(0, 1),
    balance >= 100,
  );
  final int coinsNeeded;
  final double fraction;
  final bool affordable;
}
