class SalesInvoiceDetailRow {
  final String billNo;
  final int    itemCode;
  final String batch;          // <- now maps 'batchno'
  final double qty;
  final double salesPrice;
  final double lineTotal;
  final double purchasePrice;
  final String packing;

  SalesInvoiceDetailRow({
    required this.billNo,
    required this.itemCode,
    required this.batch,
    required this.qty,
    required this.salesPrice,
    required this.lineTotal,
    required this.purchasePrice,
    required this.packing,
  });

  factory SalesInvoiceDetailRow.fromCsv(Map<String, dynamic> r) {
    double _n(String k) => (r[k] as num?)?.toDouble() ?? 0.0;

    return SalesInvoiceDetailRow(
      billNo        : r['billno']?.toString() ?? '',
      itemCode      : (r['itemcode'] as num?)?.toInt() ?? 0,
      batch         : r['batchno']?.toString() ?? '',   //  <-- MUST be 'batchno'
      qty           : _n('qty'),
      salesPrice    : _n('salesprice'),
      lineTotal     : _n('total'),
      purchasePrice : _n('purcprice'),
      packing       : r['packing']?.toString() ?? '',
    );
  }

}
