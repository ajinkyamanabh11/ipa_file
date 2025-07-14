import 'package:demo/util/customerLedger_util.dart';

class AllAccountsModel{
  final int transactionNo;
  final String transactionType;
  final int accountCode;
  final DateTime transactiondate;
  final int? invoiveNo;
  final double amount;
  final bool isCash;
  final bool isDr;
  final String narrations;

  AllAccountsModel({
    required this.transactionNo,
    required this.transactionType,
    required this.accountCode,
    required this.transactiondate,
    required this.invoiveNo,
    required this.amount,
    required this.isCash,
    required this.isDr,
    required this.narrations
});
  factory AllAccountsModel.fromMap(Map<String,dynamic>original){
    final m=lowerMap(original);
    return AllAccountsModel(
      transactionNo: int.tryParse(m['transactionno'].toString())??0,
      transactionType: m['transactiontype']?.toString()??'',
      accountCode:int.tryParse(m['accountCode']?.toString()??"")??0,
      transactiondate: parseFlexibleDate(m['transactiondate']),
      invoiveNo: int.tryParse(m['invoiceno']?.toString()??""),
      amount: double.tryParse(m['amount']?.toString()??"")??0,
      isCash: m['isitCash']?.toString().toLowerCase()=='true',
      isDr: m["isitdr"]?.toString().toLowerCase()=='true',
      narrations: m['narrations']?.toString()??"",
    );
  }
}