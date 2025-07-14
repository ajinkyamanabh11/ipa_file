import '../util/customerLedger_util.dart';
class AccountModel {
  final int accountNumber;
  final String accountName;
  final double openingBalance;
  final String type; // customer / supplier / etc.

  AccountModel({
    required this.accountNumber,
    required this.accountName,
    required this.openingBalance,
    required this.type,
  });

  factory AccountModel.fromMap(Map<String, dynamic> original) {
    final m = lowerMap(original);
    return AccountModel(
      accountNumber   : int.tryParse(m['accountnumber'].toString()) ?? 0,
      accountName     : m['accountname']?.toString() ?? '',
      openingBalance  : double.tryParse(m['openingbalance']?.toString() ?? '') ?? 0,
      type            : m['is_customer_supplier']?.toString() ?? '',
    );
  }
}

