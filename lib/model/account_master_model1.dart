import 'package:demo/util/customerLedger_util.dart';

class AccountModel{
  final int accountNumber;
  final String accountName;
  final double openingBalance;
  final String type;

  AccountModel({
    required this.accountName,
    required this.accountNumber,
    required this.openingBalance,
    required this.type,
});
  factory AccountModel.fromMap(Map<String,dynamic>original){
    final m= lowerMap(original);
    return AccountModel(
      accountName: m['accountname']?.toString()??'',
      accountNumber: int.tryParse(m['accountnumber'].toString())??0,
      openingBalance: double.tryParse(m['openingbalance']?.toString()??" ")??0,
      type:m["is_customer_supplier"]?.toString()??"",
    );
  }
}