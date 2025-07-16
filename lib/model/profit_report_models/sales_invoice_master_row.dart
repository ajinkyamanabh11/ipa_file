/// One row of SalesInvoiceMaster.csv
class SalesInvoiceMasterRow {
  final String   billNo;     // Billno
  final DateTime entryDate;  // entrydate

  SalesInvoiceMasterRow({
    required this.billNo,
    required this.entryDate,
  });

  factory SalesInvoiceMasterRow.fromCsv(Map<String, dynamic> r) {
    String raw = r['entrydate']?.toString() ?? '';
    // CSV usually exports ISO dates; adjust the parse pattern if needed
    return SalesInvoiceMasterRow(
      billNo    : r['Billno']?.toString() ?? '',
      entryDate : raw.isEmpty ? DateTime(1900) : DateTime.parse(raw),
    );
  }
}
