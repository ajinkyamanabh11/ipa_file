/// One row of SalesInvoiceDetails.csv
class SalesInvoiceDetailRow {
  final String billNo;           // Billno
  final int    itemCode;         // Itemcode
  final double qty;              // qty
  final double salesPrice;       // salesprice (unit)
  final double lineTotal;        // total (amount)
  final double purchasePrice;    // PurcPrice (unit cost)
  final String packing;          // Packing
  final String itemTypeName;     // ItemTypeName

  SalesInvoiceDetailRow({
    required this.billNo,
    required this.itemCode,
    required this.qty,
    required this.salesPrice,
    required this.lineTotal,
    required this.purchasePrice,
    required this.packing,
    required this.itemTypeName,
  });

  factory SalesInvoiceDetailRow.fromCsv(Map<String, dynamic> r) {
    double _num(String k) => (r[k] as num?)?.toDouble() ?? 0.0;
    return SalesInvoiceDetailRow(
      billNo        : r['Billno']      ?.toString() ?? '',
      itemCode      : (r['Itemcode']   as num?)?.toInt() ?? 0,
      qty           : _num('qty'),
      salesPrice    : _num('salesprice'),
      lineTotal     : _num('total'),
      purchasePrice : _num('PurcPrice'),
      packing       : r['Packing']     ?.toString() ?? '',
      itemTypeName  : r['ItemTypeName']?.toString() ?? '',
    );
  }
}
