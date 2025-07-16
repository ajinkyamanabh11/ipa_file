class SaleDetail {
  final String invoiceNo;
  final int    itemCode;
  final String itemName;
  final String packing;
  final double quantity;
  final double purchasePrice;  // unit cost
  final double sellingPrice;   // unit price
  final double profit;         // lineTotal − (qty × purchasePrice)

  SaleDetail({
    required this.invoiceNo,
    required this.itemCode,
    required this.itemName,
    required this.packing,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.profit,
  });
}
