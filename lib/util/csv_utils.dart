// lib/util/csv_utils.dart

import 'package:csv/csv.dart';
import 'dart:async';
import 'dart:isolate';

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

  /// Processes CSV data in an isolate to avoid blocking the main thread
  static Future<List<Map<String, dynamic>>> toMapsAsync(
      String csvString, {
        List<String> stringColumns = const [],
      }) async {
    if (csvString.trim().isEmpty) {
      return [];
    }

    // For very small datasets, process synchronously to avoid isolate overhead
    if (csvString.length < 50000) {
      return toMaps(csvString, stringColumns: stringColumns);
    }

    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _processCsvInIsolate,
      _CsvProcessingData(
        csvString: csvString,
        stringColumns: stringColumns,
        sendPort: receivePort.sendPort,
      ),
    );

    final result = await receivePort.first as List<Map<String, dynamic>>;
    return result;
  }

  /// Streams CSV data processing for very large datasets
  static Stream<List<Map<String, dynamic>>> toMapsStream(
      String csvString, {
        List<String> stringColumns = const [],
        int chunkSize = 1000,
      }) async* {
    if (csvString.trim().isEmpty) {
      return;
    }

    final converter = const CsvToListConverter(eol: '\n');
    List<List<dynamic>> rowsAsListOfValues = converter.convert(csvString);

    if (rowsAsListOfValues.isEmpty) {
      return;
    }

    List<String> headers = rowsAsListOfValues[0]
        .map((e) => e.toString().trim())
        .toList();

    // Process data in chunks
    for (int startIndex = 1; startIndex < rowsAsListOfValues.length; startIndex += chunkSize) {
      final endIndex = (startIndex + chunkSize < rowsAsListOfValues.length) 
          ? startIndex + chunkSize 
          : rowsAsListOfValues.length;
      
      List<Map<String, dynamic>> chunk = [];
      
      for (int i = startIndex; i < endIndex; i++) {
        Map<String, dynamic> rowMap = {};
        List<dynamic> rowValues = rowsAsListOfValues[i];

        for (int j = 0; j < headers.length; j++) {
          final header = headers[j];
          final value = (j < rowValues.length) ? rowValues[j] : null;

          if (stringColumns.contains(header)) {
            rowMap[header] = value?.toString().trim() ?? '';
          } else {
            rowMap[header] = value;
          }
          
          if (header.isNotEmpty) {
            if (stringColumns.contains(header)) {
              rowMap[header.toLowerCase()] = value?.toString().trim() ?? '';
            } else {
              rowMap[header.toLowerCase()] = value;
            }
          }
        }
        chunk.add(rowMap);
      }
      
      yield chunk;
      
      // Allow other tasks to run
      await Future.delayed(Duration.zero);
    }
  }

  /// Processes CSV data with pagination support
  static List<Map<String, dynamic>> toMapsWithPagination(
      String csvString, {
        List<String> stringColumns = const [],
        int page = 0,
        int pageSize = 100,
      }) {
    if (csvString.trim().isEmpty) {
      return [];
    }

    final converter = const CsvToListConverter(eol: '\n');
    List<List<dynamic>> rowsAsListOfValues = converter.convert(csvString);

    if (rowsAsListOfValues.isEmpty) {
      return [];
    }

    List<String> headers = rowsAsListOfValues[0]
        .map((e) => e.toString().trim())
        .toList();

    final startIndex = 1 + (page * pageSize);
    final endIndex = (startIndex + pageSize < rowsAsListOfValues.length) 
        ? startIndex + pageSize 
        : rowsAsListOfValues.length;

    if (startIndex >= rowsAsListOfValues.length) {
      return [];
    }

    List<Map<String, dynamic>> result = [];

    for (int i = startIndex; i < endIndex; i++) {
      Map<String, dynamic> rowMap = {};
      List<dynamic> rowValues = rowsAsListOfValues[i];

      for (int j = 0; j < headers.length; j++) {
        final header = headers[j];
        final value = (j < rowValues.length) ? rowValues[j] : null;

        if (stringColumns.contains(header)) {
          rowMap[header] = value?.toString().trim() ?? '';
        } else {
          rowMap[header] = value;
        }
        
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

  /// Gets the total row count without processing all data
  static int getRowCount(String csvString) {
    if (csvString.trim().isEmpty) {
      return 0;
    }
    
    // Count newlines for a quick row count estimation
    final lines = csvString.split('\n').where((line) => line.trim().isNotEmpty).length;
    return lines > 0 ? lines - 1 : 0; // Subtract 1 for header
  }
}

// Data class for isolate communication
class _CsvProcessingData {
  final String csvString;
  final List<String> stringColumns;
  final SendPort sendPort;

  _CsvProcessingData({
    required this.csvString,
    required this.stringColumns,
    required this.sendPort,
  });
}

// Isolate function for CSV processing
void _processCsvInIsolate(_CsvProcessingData data) {
  try {
    final result = CsvUtils.toMaps(
      data.csvString,
      stringColumns: data.stringColumns,
    );
    data.sendPort.send(result);
  } catch (e) {
    data.sendPort.send(<Map<String, dynamic>>[]);
  }
}