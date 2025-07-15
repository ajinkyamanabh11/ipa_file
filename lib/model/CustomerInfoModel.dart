import 'package:demo/util/customerLedger_util.dart';

class CustomerInfoModel{
  final int accountNumber;
  final String mobile;
  final String area;
  
  CustomerInfoModel({
    required this.accountNumber,
    required this.mobile,
    required this.area,
});
  factory CustomerInfoModel.fromMap(Map<String,dynamic> m){
    final map=lowerMap(m);
    return CustomerInfoModel(
      accountNumber: int.tryParse(map['accountnumber'].toString()) ?? 0,
      mobile: map['mobile']?.toString() ?? '',
      area: map['area']?.toString() ?? '',
    );
  }
  
}