class DebtorModel {
  final String name;
  final String type;  // customer / supplier
  final double openingBalance;
  final double closingBalance;
  final String drCr; // Dr / Cr
  final String mobile;
  final String area;

  DebtorModel({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.closingBalance,
    required this.drCr,
    required this.mobile,
    required this.area,
  });
}
