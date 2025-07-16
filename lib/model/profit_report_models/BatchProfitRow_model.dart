class BatchProfitRow {
  final String date;          // yyyy‑MM‑dd
  final String invoiceNo;     // first bill in the batch
  final String batch;         // batchno
  final int    itemCode;
  final String itemName;
  final String packing;
  final double quantity;
  final double salesAmount;
  final double purchaseAmount;
  final double profit;

  BatchProfitRow({
    required this.date,
    required this.invoiceNo,
    required this.batch,
    required this.itemCode,
    required this.itemName,
    required this.packing,
    required this.quantity,
    required this.salesAmount,
    required this.purchaseAmount,
    required this.profit,
  });
}
