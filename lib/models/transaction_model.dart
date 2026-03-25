class TransactionModel {
  final int id;
  final int accountId;

  /// Types: 'deposit', 'withdraw', 'transfer_out', 'transfer_in',
  ///        'salary', 'bill_paid', 'leftover', 'initial'
  final String type;
  final double amount;
  final String title;
  final String note;
  final int? relatedAccountId;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.title,
    this.note = '',
    this.relatedAccountId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'account_id': accountId,
        'type': type,
        'amount': amount,
        'title': title,
        'note': note,
        'related_account_id': relatedAccountId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as int,
        accountId: map['account_id'] as int,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        title: map['title'] as String? ?? '',
        note: map['note'] as String? ?? '',
        relatedAccountId: map['related_account_id'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
