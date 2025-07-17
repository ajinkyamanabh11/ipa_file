class ProfitEntry {
  final String packing;
  final String itemName;
  final String batch;
  final int quantity;
  final double salesAmt;
  final double purchaseAmt;
  final double profit;
  final String date;

  ProfitEntry({
    required this.packing,
    required this.itemName,
    required this.batch,
    required this.quantity,
    required this.salesAmt,
    required this.purchaseAmt,
    required this.profit,
    required this.date,
  });
}
