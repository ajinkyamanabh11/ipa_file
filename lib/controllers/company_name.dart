import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

final _storage = GetStorage();

Future<String> fetchCompanyNameFromDrive() async {
  // 1️⃣ Return cached version immediately if exists
  final cachedName = _storage.read('companyname');
  if (cachedName != null) {
    // Start re-fetching latest in background
    _refreshCompanyName();
    return cachedName;
  }

  // 2️⃣ Otherwise, fetch from Drive and cache
  return await _refreshCompanyName();
}

Future<String> _refreshCompanyName() async {
  try {
    final drive = Get.find<GoogleDriveService>();
    final path = await SoftAgriPath.build(drive);
    final folderId = await drive.folderId(path);
    final fileId = await drive.fileId('selfinformation.csv', folderId);
    final csv = await drive.downloadCsv(fileId);
    final rows = CsvUtils.toMaps(csv);

    if (rows.isNotEmpty && rows.first['companyname'] != null) {
      final name = rows.first['companyname'].toString();
      _storage.write('companyname', name); // ✅ save to cache
      return name;
    }

    return 'Company Name'; // fallback
  } catch (e) {
    print('[fetchCompanyNameFromDrive] Error: $e');
    return _storage.read('companyname') ?? 'Company Name'; // use fallback if available
  }
}
