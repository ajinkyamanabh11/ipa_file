// lib/controllers/sales_controller.dart
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'google_signin_controller.dart';

class SalesController extends GetxController {
  // ─── reactive state ──────────────────────────────────────────
  final sales     = <Map<String, dynamic>>[].obs; // every row of CSV
  final isLoading = false.obs;
  final error     = RxnString();

  late final GoogleSignInController _google;

  // ─── lifecycle ───────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _google = Get.find<GoogleSignInController>();
    fetchSales();
  }

  // ─── PUBLIC: fetch the CSV from Drive ────────────────────────
  Future<void> fetchSales() async {
    isLoading.value = true;
    error.value = null;

    try {
      // 0️⃣ auth header
      final auth = await _google.getAuthHeaders();
      if (auth == null) throw Exception('Missing auth headers');
      final headers = {'Authorization': auth['Authorization']!};

      // 1️⃣ walk folders   SoftAgri_Backups/20252026/softagri_csv
      final folderNames = ['SoftAgri_Backups', '20252026', 'softagri_csv'];
      String? parentId;
      for (final folder in folderNames) {
        final q = [
          "name='$folder'",
          "mimeType='application/vnd.google-apps.folder'",
          "'${parentId ?? 'root'}' in parents",
          "trashed=false",
        ].join(' and ');
        final res = await http.get(
          Uri.parse(
              'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id)&spaces=drive'),
          headers: headers,
        );
        final files = (json.decode(res.body)['files'] as List);
        if (files.isEmpty) throw Exception("Folder '$folder' not found");
        parentId = files.first['id'];
      }

      // 2️⃣ find file id
      final fileId =
      await _findFileId('SalesInvoiceMaster.csv', parentId!, headers);

      // 3️⃣ download CSV
      final csvRes = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: headers,
      );
      if (csvRes.statusCode != 200) {
        throw Exception('Download failed (${csvRes.statusCode})');
      }

      // 4️⃣ parse CSV  +  alias real headers to UI keys  -------------
      final rows   = const CsvToListConverter(eol: '\n').convert(csvRes.body);
      final header = rows.first.map((e) => e.toString().trim()).toList();

      final List<Map<String, dynamic>> parsed = [];

      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        final m = <String, dynamic>{};

        // raw fields
        for (var c = 0; c < header.length && c < r.length; c++) {
          final key = header[c];
          m[key] = r[c];                       // original case
          m[key.toLowerCase()] = r[c];         // convenience lower‑case
        }

        // ── aliases expected by the UI ───────────────────────────
        m['AccountName'] = m['accountname'];
        m['BillNo']      = m['billno'];              // use 'invoiceno' if preferred
        m['PaymentMode'] = m['paymentmode'];
        m['Amount']      =
            double.tryParse('${m['totalbillamount']}') ?? 0.0;

        // EntryDate : from 'invoicedate' (fallback 'entrydate')
        String rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
        if (rawDate.isNotEmpty && rawDate != 'null') {
          try {
            m['EntryDate'] = DateTime.parse(rawDate.split(' ').first);
          } catch (_) {/* keep null if format unexpected */}
        }

        parsed.add(m);
      }

      sales.value = parsed;                     // ← finished parsing
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ─── helpers ─────────────────────────────────────────────────
  double get totalCash => sales
      .where((s) => s['PaymentMode'].toString().toLowerCase() == 'cash')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  double get totalCredit => sales
      .where((s) => s['PaymentMode'].toString().toLowerCase() == 'credit')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  List<Map<String, dynamic>> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) =>
      sales.where((s) {
        final n = s['AccountName']
            ?.toString()
            .toLowerCase()
            .contains(nameQ.toLowerCase()) ??
            false;
        final b = s['BillNo']
            ?.toString()
            .toLowerCase()
            .contains(billQ.toLowerCase()) ??
            false;
        final d = date == null ||
            (s['EntryDate'] is DateTime &&
                DateUtils.isSameDay(s['EntryDate'], date));
        return n && b && d;
      }).toList();

  // find file helper
  Future<String> _findFileId(
      String name, String parent, Map<String, String> headers) async {
    final q = Uri.encodeQueryComponent("name='$name' and '$parent' in parents");
    final res = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id)'),
      headers: headers,
    );
    final list = (json.decode(res.body)['files'] as List);
    if (list.isEmpty) throw Exception("File '$name' not found");
    return list.first['id'];
  }
}
