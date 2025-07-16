import 'package:intl/intl.dart';

class SalesInvoiceMasterRow {
  final String   billNo;
  final DateTime invoiceDate;

  SalesInvoiceMasterRow({
    required this.billNo,
    required this.invoiceDate,
  });

  factory SalesInvoiceMasterRow.fromCsv(Map<String, dynamic> r) {
    // bill number (trim to remove stray spaces)
    final bill = r['billno']?.toString().trim() ?? '';

    // raw string in CSV – could be "01/May/2025", "1‑5‑25", "2025‑05‑01"…
    final raw  = (r['invoicedate'] ?? '').toString().trim();

    DateTime _parse(String s) {
      if (s.isEmpty) return DateTime(1900);

      // try a list of formats from most to least likely
      const fmts = [
        'yyyy-MM-dd',        // 2025-05-01
        'd/MMM/yyyy',        // 1/May/2025
        'dd/MMM/yyyy',       // 01/May/2025
        'd-MMM-yyyy',        // 1-May-2025
        'dd-MMM-yyyy',       // 01-May-2025
        'd/M/yyyy',          // 1/5/2025
        'dd/MM/yyyy',        // 01/05/2025
        'd-M-yyyy',          // 1-5-2025
        'dd-MM-yyyy',        // 01-05-2025
      ];

      // 1) ISO first
      try { return DateTime.parse(s); } catch (_) {}

      // 2) custom formats
      for (final f in fmts) {
        try { return DateFormat(f).parseStrict(s); } catch (_) {}
      }

      // 3) give up – log once so you know what’s wrong
      // ignore: avoid_print
      print('[SalesInvoiceMasterRow] ⚠️  Could not parse date "$s" for bill "$bill"');
      return DateTime(1900);
    }

    return SalesInvoiceMasterRow(
      billNo      : bill,
      invoiceDate : _parse(raw),
    );
  }
}
