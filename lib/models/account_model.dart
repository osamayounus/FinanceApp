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
  final double balance;
  final String? customName;
  final int? colorIndex;
  final int? iconCode;

  const AccountModel({
    required this.id,
    required this.type,
    required this.balance,
    this.customName,
    this.colorIndex,
    this.iconCode,
  });

  bool get isCustom => type == AccountType.custom;

  String get displayName =>
      isCustom ? (customName ?? 'Account') : type.displayName;

  AccountModel copyWith({
    double? balance,
    String? customName,
    int? colorIndex,
    int? iconCode,
  }) {
    return AccountModel(
      id: id,
      type: type,
      balance: balance ?? this.balance,
      customName: customName ?? this.customName,
      colorIndex: colorIndex ?? this.colorIndex,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.key,
        'balance': balance,
        'custom_name': customName,
        'color_index': colorIndex,
        'icon_code': iconCode,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as int,
        type: AccountTypeExt.fromKey(map['type'] as String),
        balance: (map['balance'] as num).toDouble(),
        customName: map['custom_name'] as String?,
        colorIndex: map['color_index'] as int?,
        iconCode: map['icon_code'] as int?,
      );
}
