// Fixed account IDs
const kWalletId = 1;
const kBudgetId = 2;
const kSavingsId = 3;

enum AccountType { wallet, budget, savings }

extension AccountTypeExt on AccountType {
  String get key {
    switch (this) {
      case AccountType.wallet:
        return 'wallet';
      case AccountType.budget:
        return 'budget';
      case AccountType.savings:
        return 'savings';
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
      default:
        return AccountType.wallet;
    }
  }
}

class AccountModel {
  final int id;
  final AccountType type;
  final double balance;

  const AccountModel({
    required this.id,
    required this.type,
    required this.balance,
  });

  AccountModel copyWith({double? balance}) {
    return AccountModel(id: id, type: type, balance: balance ?? this.balance);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.key,
        'balance': balance,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as int,
        type: AccountTypeExt.fromKey(map['type'] as String),
        balance: (map['balance'] as num).toDouble(),
      );
}
