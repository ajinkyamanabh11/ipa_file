import 'sale_detail.dart';

class ItemProfitSummary {
  final int    itemCode;
  final String itemName;
  final String packing;
  final double totalQty;
  final double totalSales;
  final double totalPurchase;
  final double totalProfit;

  ItemProfitSummary({
    required this.itemCode,
    required this.itemName,
    required this.packing,
    required this.totalQty,
    required this.totalSales,
    required this.totalPurchase,
    required this.totalProfit,
  });

  factory ItemProfitSummary.fromSales(List<SaleDetail> sales) {
    if (sales.isEmpty) {
      return ItemProfitSummary(
        itemCode: 0,
        itemName: 'Unknown',
        packing : '',
        totalQty: 0,
        totalSales: 0,
        totalPurchase: 0,
        totalProfit: 0,
      );
    }
    return ItemProfitSummary(
      itemCode   : sales.first.itemCode,
      itemName   : sales.first.itemName,
      packing    : sales.first.packing,
      totalQty   : sales.fold(0, (s, e) => s + e.quantity),
      totalSales : sales.fold(0, (s, e) => s + e.sellingPrice  * e.quantity),
      totalPurchase : sales.fold(0, (s, e) => s + e.purchasePrice * e.quantity),
      totalProfit   : sales.fold(0, (s, e) => s + e.profit),
    );
  }
}
