import 'package:intl/intl.dart';

class SalesInvoiceMasterRow {
  final String invoiceno;
  final DateTime invoiceDate;

  SalesInvoiceMasterRow({
    required this.invoiceno,
    required this.invoiceDate,
  });

  factory SalesInvoiceMasterRow.fromCsv(Map<String, dynamic> r) {
    final bill = r['invoiceno']?.toString().trim() ?? '';

    final rawDate = (r['invoicedate'] ?? '').toString().trim();

    DateTime _parse(String s) {
      if (s.isEmpty) return DateTime(1900);

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
        'd-M-yy',            // 1-5-25
        'dd-MM-yy',          // 01-05-25
        'd/MM/yy',           // 1/05/25
        'dd/MM/yy',          // 01/05/25
        'yyyy/MM/dd',        // 2025/05/01
      ];

      try {
        return DateTime.parse(s);
      } catch (_) {}

      for (final f in fmts) {
        try {
          return DateFormat(f).parseStrict(s);
        } catch (_) {}
      }

      // ignore: avoid_print
      print('[SalesInvoiceMasterRow] ⚠️  Could not parse date "$s" for bill "$bill"');
      return DateTime(1900);
    }

    return SalesInvoiceMasterRow(
      invoiceno: bill,
      invoiceDate: _parse(rawDate),
    );
  }
}
