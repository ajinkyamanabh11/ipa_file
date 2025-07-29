// lib/util/csv_worker.dart
import 'dart:convert';

Future<Map<String, dynamic>> parseAndCacheCsv(Map<String, dynamic> args) async {
  final String key = args['key'];
  final String csvData = args['csvData'];

  final double estimatedSizeMB = (csvData.length * 2) / (1024 * 1024); // UTF-8 * 2 for Dart string
  return {
    'key': key,
    'csvData': csvData,
    'estimatedSizeMB': estimatedSizeMB,
  };
}
