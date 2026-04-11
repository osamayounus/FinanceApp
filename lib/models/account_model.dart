// Fixed account IDs
const kWalletId = 1;
const kBudgetId = 2;
const kSavingsId = 3;

enum AccountType { wallet, budget, savings, custom }

extension AccountTypeExt on AccountType {
  String get key {
    switch (this) {
      case AccountType.wallet:
        return 'wallet';
      case AccountType.budget:
        return 'budget';
      case AccountType.savings:
        return 'savings';
      case AccountType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.budget:
        return 'Monthly Budget';
      case AccountType.savings:
        return 'Savings';
      case AccountType.custom:
        return 'Account';
    }
  }

  static AccountType fromKey(String key) {
    switch (key) {
      case 'wallet':
        return AccountType.wallet;
      case 'budget':
        return AccountType.budget;
      case 'savings':
        return AccountType.savings;
      case 'custom':
        return AccountType.custom;
      default:
        return AccountType.wallet;
    }
  }
}

class AccountModel {
  final int id;
  final AccountType type;
  /// Available balance — the amount the user can actually spend.
  final double balance;
  /// Amount currently lent out (debt given). Not spendable until repaid.
  final double loanedAmount;
  final String? customName;
  final int? colorIndex;
  final int? iconCode;

  const AccountModel({
    required this.id,
    required this.type,
    required this.balance,
    this.loanedAmount = 0.0,
    this.customName,
    this.colorIndex,
    this.iconCode,
  });

  /// Total net worth = available + lent out.
  double get totalBalance => balance + loanedAmount;

  bool get isCustom => type == AccountType.custom;

  String get displayName =>
      isCustom ? (customName ?? 'Account') : type.displayName;

  AccountModel copyWith({
    double? balance,
    double? loanedAmount,
    String? customName,
    int? colorIndex,
    int? iconCode,
  }) {
    return AccountModel(
      id: id,
      type: type,
      balance: balance ?? this.balance,
      loanedAmount: loanedAmount ?? this.loanedAmount,
      customName: customName ?? this.customName,
      colorIndex: colorIndex ?? this.colorIndex,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.key,
        'balance': balance,
        'loaned_amount': loanedAmount,
        'custom_name': customName,
        'color_index': colorIndex,
        'icon_code': iconCode,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as int,
        type: AccountTypeExt.fromKey(map['type'] as String),
        balance: (map['balance'] as num).toDouble(),
        loanedAmount: (map['loaned_amount'] as num?)?.toDouble() ?? 0.0,
        customName: map['custom_name'] as String?,
        colorIndex: map['color_index'] as int?,
        iconCode: map['icon_code'] as int?,
      );
}
