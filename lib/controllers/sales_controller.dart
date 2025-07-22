import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../services/CsvDataServices.dart'; // NEW IMPORT for CsvDataService
import 'base_remote_controller.dart';
import 'dart:developer'; // For logging

class SalesController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>(); // NEW: Get CsvDataService instance

  // ─────────────────────────────────────────────────────────────
  // REMOVED: _softAgriPath is no longer needed here as CsvDataService handles it
  // late final List<String> _softAgriPath;

  final sales = <Map<String, dynamic>>[].obs;

  // ───────────────────────── life‑cycle ────────────────────────
  @override
  Future<void> onInit() async {
    super.onInit();

    // REMOVED: _softAgriPath build is no longer needed here
    // _softAgriPath = await SoftAgriPath.build(drive);

    // Initial fetch, now potentially forcing a refresh of CSVs for the first load
    log('[SalesController] Initializing and loading sales data...');
    guard(() => _loadSales(forceRefresh: true)); // Force refresh on initial load for freshness
  }

  /// Pull‑to‑refresh entrypoint
  // Added forceRefresh parameter to allow refreshing the underlying CSVs
  Future<void> fetchSales({bool forceRefresh = false}) async => guard(() => _loadSales(forceRefresh: forceRefresh));

  // ───────────────────────── CSV fetch + parse ─────────────────
  // Modified _loadSales to use CsvDataService
  Future<void> _loadSales({bool forceRefresh = false}) async {
    try {
      // 🔴 CRITICAL CHANGE: Load all necessary CSVs via CsvDataService
      // This will either get from cache or download fresh based on forceRefresh and cache validity
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      // Get the raw sales master CSV string from CsvDataService
      final String csv = _csvDataService.salesMasterCsv.value;

      // Check if CSV data is actually available after the service call
      if (csv.isEmpty) {
        log('⚠️ SalesController: SalesInvoiceMaster.csv data is empty. Cannot process sales.');
        sales.clear(); // Clear existing sales data
        // Optionally, set an error message if you have an RxString error field
        // errorMessage.value = 'Failed to load sales data. Please try again.';
        return; // Exit function if data is not available
      }

      log('⚡ SalesController: Processing SalesInvoiceMaster.csv (from cache or new download)');

      // map & normalise fields
      sales.value = CsvUtils.toMaps(csv, parseNumbers: false).map((m) {
        m['AccountName'] = m['accountname'];
        m['BillNo']      = m['billno'];
        m['PaymentMode'] = m['paymentmode'];
        m['Amount']      = double.tryParse('${m['totalbillamount']}') ?? 0.0;

        final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
        if (rawDate.isNotEmpty && rawDate != 'null') {
          try {
            // keep only yyyy‑MM‑dd part
            m['EntryDate'] = DateTime.parse(rawDate.split(' ').first);
          } catch (_) {/* ignore parse errors */}
        }
        return m;
      }).toList();
      log('✅ SalesController: Sales data processed successfully. Count: ${sales.length}');

    } catch (e, st) {
      log('[SalesController] ❌ Error loading sales data: $e\n$st');
      sales.clear(); // Clear data on error
      // Optionally, set an error message
      // errorMessage.value = 'Failed to load sales data: $e';
    } finally {
      // Assuming `isLoading` is managed by BaseRemoteController's `guard`
      // If you have a local `isLoading` RxBool, manage it here.
    }
  }

  // ─────────────────────── computed getters ────────────────────
  double get totalCash => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'cash')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  double get totalCredit => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'credit')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  // ─────────────────────── local filters ───────────────────────
  List<Map<String, dynamic>> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) =>
      sales.where((s) {
        final name = s['AccountName']?.toString().toLowerCase() ?? '';
        final bill = s['BillNo']?.toString().toLowerCase() ?? '';
        final dateMatch = date == null ||
            (s['EntryDate'] is DateTime &&
                DateUtils.isSameDay(s['EntryDate'], date));

        return name.contains(nameQ.toLowerCase()) &&
            bill.contains(billQ.toLowerCase()) &&
            dateMatch;
      }).toList();
}