// lib/constants/softagri_path.dart
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

class SoftAgriPath {
  static const String _ROOT = 'Softagri_Backups';
  static const String _LEAF = 'softagri_csv';

  /// Returns the path: ['Softagri_Backups', '<yyyyyyyy+1>', 'softagri_csv']
  static Future<List<String>> build(GoogleDriveService drive) async {
    try {
      // 1️⃣  locate the top‑level "Financialyear_csv" folder
      final fyFolderId = await drive.folderId(['Financialyear_csv']);

      // 2️⃣  download FinancialYear.csv
      final fileId = await drive.fileId('FinancialYear.csv', fyFolderId);
      final csv    = await drive.downloadCsv(fileId);

      // 3️⃣  parse – we only care about the row where CurrentYear is ticked
      final rows   = CsvUtils.toMaps(csv);   // util that turns header→map rows
      final active = rows.firstWhere(
            (r) => _isChecked(r['CurrentYear']),
        orElse: () => <String, dynamic>{},
      );

      if (active.isEmpty) throw 'No CurrentYear == true row found';

      final startDate = DateTime.parse(active['StartDate'].toString());
      final startYr   = startDate.year;
      final folder    = '$startYr${startYr + 1}';

      return [_ROOT, folder, _LEAF];
    } catch (e) {
      // fallback keeps the app alive if Drive/db is unreachable
      print('[SoftAgriPath] ⚠️ using fallback year (reason: $e)');
      return [_ROOT, '20252026', _LEAF];
    }
  }

  // Accept 1 / true / yes  (case‑insensitive) as “ticked”
  static bool _isChecked(dynamic v) {
    final str = v?.toString().toLowerCase() ?? '';
    return str == '1' || str == 'true' || str == 'yes';
  }
}
