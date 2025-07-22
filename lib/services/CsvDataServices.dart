// lib/services/csv_data_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';

import '../constants/paths.dart';
import 'google_drive_service.dart';

class CsvDataService extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final GetStorage _box = GetStorage();

  static const String _salesMasterCacheKey = 'salesMasterCsv';
  static const String _salesDetailsCacheKey = 'salesDetailsCsv';
  static const String _itemMasterCacheKey = 'itemMasterCsv';
  static const String _itemDetailCacheKey = 'itemDetailCsv';

  static const String _accountMasterCacheKey = 'accountMasterCsv';
  static const String _allAccountsCacheKey = 'allAccountsCsv';
  static const String _customerInfoCacheKey = 'customerInfoCsv';
  static const String _supplierInfoCacheKey = 'supplierInfoCsv';

  static const String _lastCsvSyncTimestampKey = 'lastCsvSync';

  // Adjusted cache duration for testing, consider making it longer in production
  static const Duration _cacheDuration = Duration(minutes: 1); // Shorter cache for easier testing

  final RxString salesMasterCsv = ''.obs;
  final RxString salesDetailsCsv = ''.obs;
  final RxString itemMasterCsv = ''.obs;
  final RxString itemDetailCsv = ''.obs;

  final RxString accountMasterCsv = ''.obs;
  final RxString allAccountsCsv = ''.obs;
  final RxString customerInfoCsv = ''.obs;
  final RxString supplierInfoCsv = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Potentially load from cache on init, but don't force download
    // loadAllCsvs(forceDownload: false); // Or load specific ones if needed
  }

  /// Loads all required CSVs, either from cache or by downloading from Google Drive.
  /// If [forceDownload] is true, it will always download new data, ignoring cache validity.
  /// This method now handles ALL primary CSVs used throughout the app.
  Future<void> loadAllCsvs({bool forceDownload = false}) async {
    log('🔄 CsvDataService: Starting loadAllCsvs (Force download requested: $forceDownload)');

    final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
    final isCacheValid = lastSync != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

    // List of all CSV keys
    final List<String> allCsvKeys = [
      _salesMasterCacheKey, _salesDetailsCacheKey, _itemMasterCacheKey, _itemDetailCacheKey,
      _accountMasterCacheKey, _allAccountsCacheKey, _customerInfoCacheKey, _supplierInfoCacheKey,
    ];

    // Determine if we need to download
    bool needsDownload = forceDownload;
    if (!forceDownload) {
      // If not forcing download, check cache validity and completeness
      if (!isCacheValid) {
        log('💡 CsvDataService: Cache is NOT valid (older than ${_cacheDuration.inMinutes} mins). Will download.');
        needsDownload = true;
      } else {
        bool anyDataMissing = false;
        for (final key in allCsvKeys) {
          final cachedData = _box.read(key);
          if (cachedData == null || cachedData.isEmpty) {
            anyDataMissing = true;
            log('⚠️ CsvDataService: Cache incomplete for key: $key. Will download.');
            break;
          }
        }
        if (anyDataMissing) {
          needsDownload = true;
        } else {
          log('✅ CsvDataService: All CSVs found in valid cache. Populating reactive variables from cache.');
          for (final key in allCsvKeys) {
            _populateReactiveVarFromCache(key, _box.read(key));
          }
          return; // All data found in cache and valid, no need to download
        }
      }
    }

    if (needsDownload) {
      log('🌐 CsvDataService: Proceeding with download from Drive (Force: $forceDownload, Cache Valid: $isCacheValid).');
      try {
        final path = await SoftAgriPath.build(drive);
        final folderId = await drive.folderId(path);

        final List<Future<String>> downloadFutures = [
          drive.downloadCsv(await drive.fileId('SalesInvoiceMaster.csv', folderId)),
          drive.downloadCsv(await drive.fileId('SalesInvoiceDetails.csv', folderId)),
          drive.downloadCsv(await drive.fileId('ItemMaster.csv', folderId)),
          drive.downloadCsv(await drive.fileId('ItemDetail.csv', folderId)),
          drive.downloadCsv(await drive.fileId('AccountMaster.csv', folderId)),
          drive.downloadCsv(await drive.fileId('AllAccounts.csv', folderId)),
          drive.downloadCsv(await drive.fileId('CustomerInformation.csv', folderId)),
          drive.downloadCsv(await drive.fileId('SupplierInformation.csv', folderId)),
        ];

        final results = await Future.wait(downloadFutures);

        salesMasterCsv.value = results[0];
        await _box.write(_salesMasterCacheKey, salesMasterCsv.value);

        salesDetailsCsv.value = results[1];
        await _box.write(_salesDetailsCacheKey, salesDetailsCsv.value);

        itemMasterCsv.value = results[2];
        await _box.write(_itemMasterCacheKey, itemMasterCsv.value);

        itemDetailCsv.value = results[3];
        await _box.write(_itemDetailCacheKey, itemDetailCsv.value);

        accountMasterCsv.value = results[4];
        await _box.write(_accountMasterCacheKey, accountMasterCsv.value);

        allAccountsCsv.value = results[5];
        await _box.write(_allAccountsCacheKey, allAccountsCsv.value);

        customerInfoCsv.value = results[6];
        await _box.write(_customerInfoCacheKey, customerInfoCsv.value);

        supplierInfoCsv.value = results[7];
        await _box.write(_supplierInfoCacheKey, supplierInfoCsv.value);

        await _box.write(_lastCsvSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);

        log('💾 CsvDataService: All CSVs downloaded and cached successfully.');
      } catch (e, st) {
        log('❌ CsvDataService: Error downloading/caching CSVs: $e\n$st');
        salesMasterCsv.value = '';
        salesDetailsCsv.value = '';
        itemMasterCsv.value = '';
        itemDetailCsv.value = '';
        accountMasterCsv.value = '';
        allAccountsCsv.value = '';
        customerInfoCsv.value = '';
        supplierInfoCsv.value = '';
        // Do NOT rethrow, let the caller handle empty values.
      }
    }
  }

  void _populateReactiveVarFromCache(String key, String? cachedData) {
    if (cachedData == null || cachedData.isEmpty) return;

    switch (key) {
      case _salesMasterCacheKey: salesMasterCsv.value = cachedData; break;
      case _salesDetailsCacheKey: salesDetailsCsv.value = cachedData; break;
      case _itemMasterCacheKey: itemMasterCsv.value = cachedData; break;
      case _itemDetailCacheKey: itemDetailCsv.value = cachedData; break;
      case _accountMasterCacheKey: accountMasterCsv.value = cachedData; break;
      case _allAccountsCacheKey: allAccountsCsv.value = cachedData; break;
      case _customerInfoCacheKey: customerInfoCsv.value = cachedData; break;
      case _supplierInfoCacheKey: supplierInfoCsv.value = cachedData; break;
    }
  }

  Future<void> clearAllCsvCache() async {
    // List all keys to remove them
    final List<String> allCacheKeys = [
      _salesMasterCacheKey, _salesDetailsCacheKey, _itemMasterCacheKey, _itemDetailCacheKey,
      _accountMasterCacheKey, _allAccountsCacheKey, _customerInfoCacheKey, _supplierInfoCacheKey,
      _lastCsvSyncTimestampKey
    ];

    for (final key in allCacheKeys) {
      await _box.remove(key);
    }
    log('🗑️ CsvDataService: All CSV cache cleared.');
  }
}