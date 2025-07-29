// lib/util/csv_utils.dart

import 'package:csv/csv.dart';

class CsvUtils {
  /// Converts a raw CSV string into a list of maps.
  ///
  /// This function now explicitly handles converting specified columns
  /// to strings to preserve leading zeros or other non-numeric formats.
  ///
  /// [csvString]: The raw CSV data as a single string.
  /// [stringColumns]: A list of column headers (strings) that should
  ///   always be treated as strings, even if they look like numbers.
  ///   Examples: ['BatchNo', 'BillNo', 'ItemCode'].
  static List<Map<String, dynamic>> toMaps(
      String csvString, {
        List<String> stringColumns = const [], // This is the correct parameter
      }) {
    if (csvString.trim().isEmpty) {
      return [];
    }

    // Use CsvToListConverter without any special number parsing options,
    // as we'll handle explicit string conversion later for 'stringColumns'.
    // The default behavior of CsvToListConverter is fine for initial parsing;
    // we override specific columns to string manually.
    final converter = const CsvToListConverter(
      eol: '\n', // Ensure consistent end-of-line character
      // DO NOT put shouldParseNumbers: true/false here. We want raw values initially.
    );

    List<List<dynamic>> rowsAsListOfValues = converter.convert(csvString);

    if (rowsAsListOfValues.isEmpty) {
      return [];
    }

    // Assuming the first row is headers
    List<String> headers = rowsAsListOfValues[0]
        .map((e) => e.toString().trim())
        .toList();

    List<Map<String, dynamic>> result = [];

    for (int i = 1; i < rowsAsListOfValues.length; i++) {
      Map<String, dynamic> rowMap = {};
      List<dynamic> rowValues = rowsAsListOfValues[i];

      for (int j = 0; j < headers.length; j++) {
        final header = headers[j];
        // Handle potential index out of bounds for malformed rows
        final value = (j < rowValues.length) ? rowValues[j] : null;

        // Explicitly convert to String for specified columns
        if (stringColumns.contains(header)) {
          rowMap[header] = value?.toString().trim() ?? '';
        } else {
          // For other columns, keep their original parsed type.
          // The csv package might parse '123' as int, '1.23' as double.
          rowMap[header] = value;
        }
        // Also add the lowercase convenience key
        if (header.isNotEmpty) {
          if (stringColumns.contains(header)) {
            rowMap[header.toLowerCase()] = value?.toString().trim() ?? '';
          } else {
            rowMap[header.toLowerCase()] = value;
          }
        }
      }
      result.add(rowMap);
    }
    return result;
  }

  /// Isolate-compatible version of toMaps for use with compute
  static List<Map<String, dynamic>> toMapsFromArgs(Map<String, dynamic> args) {
    final String csvData = args['csvData'];
    final List<String> stringColumns = List<String>.from(args['stringColumns'] ?? []);
    
    return toMaps(csvData, stringColumns: stringColumns);
  }
}