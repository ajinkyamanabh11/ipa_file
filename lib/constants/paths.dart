import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

/// Returns the Drive path segments your existing code expects:
///   ['SoftAgri_Backups', '<current‑FY‑folder>', 'softagri_csv']
///
/// Call it once (during `onInit` or before the 1st download) and
/// cache the result – no need to hit Drive every time.
class SoftAgriPath {
  // ── segment 0 & 2 are fixed ────────────────────────────────────────────
  static const String _root    = 'SoftAgri_Backups';
  static const String _csvSub  = 'softagri_csv';
  static const String _finFile = 'Financialyear.csv';

  /// Build the 3‑segment list.
  static Future<List<String>> build(GoogleDriveService drive) async {
    // 1️⃣ find “SoftAgri_Backups” folder on Drive
    final rootId = await drive.folderId([_root]);

    // 2️⃣ download Financialyear.csv (always in root)
    final finCsvId  = await drive.fileId(_finFile, rootId);
    final finRows   = CsvUtils.toMaps(await drive.downloadCsv(finCsvId));

    // 3️⃣ locate the row where CurrentYear <> 0
    final current = finRows.firstWhere(
          (m) => (m['CurrentYear']?.toString() ?? '') != '0',
      orElse: () => {},
    );
    if (current.isEmpty) {
      throw 'No active Financial Year row in $_finFile';
    }

    // 4️⃣ compute the folder name, e.g. 20252026
    final start = DateTime.parse(current['StartDate']);
    final fyDir = '${start.year}${start.year + 1}';

    // 5️⃣ return the exact 3‑segment list your code already uses
    return [_root, fyDir, _csvSub];
  }
}
