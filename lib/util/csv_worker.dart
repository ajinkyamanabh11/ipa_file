// lib/util/csv_worker.dart
import 'dart:convert';
import 'dart:isolate';
import 'package:csv/csv.dart';

/// Enhanced CSV processing with proper isolate support
Future<Map<String, dynamic>> parseAndCacheCsv(Map<String, dynamic> args) async {
  final String key = args['key'];
  final String csvData = args['csvData'];
  final bool shouldParse = args['shouldParse'] ?? true;

  final double estimatedSizeMB = (csvData.length * 2) / (1024 * 1024);

  Map<String, dynamic> result = {
    'key': key,
    'csvData': csvData,
    'estimatedSizeMB': estimatedSizeMB,
  };

  // If parsing is requested, do it in isolate
  if (shouldParse && csvData.isNotEmpty) {
    try {
      final parsed = await _parseCsvInIsolate(csvData);
      result['parsedData'] = parsed;
      result['rowCount'] = parsed.length;
    } catch (e) {
      result['parseError'] = e.toString();
    }
  }

  return result;
}

/// Parse CSV data in isolate to prevent UI blocking
Future<List<Map<String, dynamic>>> _parseCsvInIsolate(String csvData) async {
  return await Isolate.run(() => _doParseCsv(csvData));
}

/// Actual CSV parsing logic that runs in isolate
List<Map<String, dynamic>> _doParseCsv(String csvData) {
  if (csvData.isEmpty) return [];

  try {
    final lines = csvData.split('\n');
    if (lines.isEmpty) return [];

    // Remove empty lines and trim
    final cleanLines = lines.where((line) => line.trim().isNotEmpty).toList();
    if (cleanLines.isEmpty) return [];

    // Parse using CSV package
    final csvTable = const CsvToListConverter().convert(cleanLines.join('\n'));
    if (csvTable.isEmpty) return [];

    final headers = csvTable.first.map((e) => e.toString().trim()).toList();
    final List<Map<String, dynamic>> result = [];

    // Convert to maps with proper type handling
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      final Map<String, dynamic> rowMap = {};

      for (int j = 0; j < headers.length && j < row.length; j++) {
        final value = row[j];
        rowMap[headers[j]] = _convertValue(value);
      }

      if (rowMap.isNotEmpty) {
        result.add(rowMap);
      }
    }

    return result;
  } catch (e) {
    // Return empty list on parse error
    return [];
  }
}

/// Convert CSV values to appropriate types
dynamic _convertValue(dynamic value) {
  if (value == null) return null;

  final stringValue = value.toString().trim();
  if (stringValue.isEmpty) return null;

  // Try to parse as number
  final numValue = num.tryParse(stringValue);
  if (numValue != null) return numValue;

  // Try to parse as boolean
  if (stringValue.toLowerCase() == 'true') return true;
  if (stringValue.toLowerCase() == 'false') return false;

  // Return as string
  return stringValue;
}

/// Process large datasets in chunks within an isolate
Future<Map<String, dynamic>> processLargeDatasetInChunks(Map<String, dynamic> args) async {
  return await Isolate.run(() => _processDatasetChunks(args));
}

/// Chunk processing logic that runs in isolate
Map<String, dynamic> _processDatasetChunks(Map<String, dynamic> args) {
  final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(args['data'] ?? []);
  final int chunkSize = args['chunkSize'] ?? 100;
  final String operation = args['operation'] ?? 'filter';
  final Map<String, dynamic> filters = args['filters'] ?? {};

  final List<Map<String, dynamic>> results = [];
  int processedCount = 0;

  // Process in chunks to prevent memory spikes
  for (int i = 0; i < data.length; i += chunkSize) {
    final chunk = data.skip(i).take(chunkSize).toList();

    switch (operation) {
      case 'filter':
        results.addAll(_filterChunk(chunk, filters));
        break;
      case 'transform':
        results.addAll(_transformChunk(chunk, filters));
        break;
      case 'aggregate':
        results.addAll(_aggregateChunk(chunk, filters));
        break;
    }

    processedCount += chunk.length;
  }

  return {
    'results': results,
    'processedCount': processedCount,
    'totalCount': data.length,
  };
}

/// Filter chunk of data
List<Map<String, dynamic>> _filterChunk(List<Map<String, dynamic>> chunk, Map<String, dynamic> filters) {
  return chunk.where((item) {
    for (final entry in filters.entries) {
      final key = entry.key;
      final expectedValue = entry.value;

      if (!item.containsKey(key)) continue;

      final actualValue = item[key];
      if (actualValue != expectedValue) return false;
    }
    return true;
  }).toList();
}

/// Transform chunk of data
List<Map<String, dynamic>> _transformChunk(List<Map<String, dynamic>> chunk, Map<String, dynamic> config) {
  return chunk.map((item) {
    final transformed = Map<String, dynamic>.from(item);

    // Apply transformations based on config
    final transformations = config['transformations'] as Map<String, dynamic>? ?? {};

    for (final entry in transformations.entries) {
      final field = entry.key;
      final transformation = entry.value;

      if (transformed.containsKey(field)) {
        switch (transformation) {
          case 'uppercase':
            transformed[field] = transformed[field].toString().toUpperCase();
            break;
          case 'lowercase':
            transformed[field] = transformed[field].toString().toLowerCase();
            break;
          case 'trim':
            transformed[field] = transformed[field].toString().trim();
            break;
        }
      }
    }

    return transformed;
  }).toList();
}

/// Aggregate chunk of data
List<Map<String, dynamic>> _aggregateChunk(List<Map<String, dynamic>> chunk, Map<String, dynamic> config) {
  final groupBy = config['groupBy'] as String?;
  if (groupBy == null) return chunk;

  final Map<String, Map<String, dynamic>> groups = {};

  for (final item in chunk) {
    final groupKey = item[groupBy]?.toString() ?? 'unknown';

    if (!groups.containsKey(groupKey)) {
      groups[groupKey] = Map<String, dynamic>.from(item);
      groups[groupKey]?['_count'] = 1;
    } else {
      groups[groupKey]!['_count'] = (groups[groupKey]!['_count'] ?? 0) + 1;

      // Aggregate numeric fields
      for (final entry in item.entries) {
        if (entry.value is num && entry.key != groupBy) {
          final currentValue = groups[groupKey]![entry.key] as num? ?? 0;
          groups[groupKey]![entry.key] = currentValue + (entry.value as num);
        }
      }
    }
  }

  return groups.values.toList();
}
