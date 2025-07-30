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

  final result = {
    'key': key,
    'csvData': csvData,
    'estimatedSizeMB': estimatedSizeMB,
    'parsedData': <Map<String, dynamic>>[],
  };

  if (shouldParse && csvData.isNotEmpty) {
    try {
      final parsed = await _parseCsvInIsolate(csvData);
      result['parsedData'] = parsed;
    } catch (e) {
      print('Error parsing CSV in isolate: $e');
      result['parsedData'] = [];
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
    // Clean the CSV data first
    final lines = csvData.split('\n');
    final cleanLines = lines.where((line) => line.trim().isNotEmpty).toList();
    
    if (cleanLines.isEmpty) return [];

    // Parse using CSV package
    final csvTable = const CsvToListConverter().convert(cleanLines.join('\n'));
    if (csvTable.isEmpty) return [];

    final headers = csvTable.first.map((e) => e.toString().trim()).toList();
    final List<Map<String, dynamic>> result = [];

    // Process data rows
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      final Map<String, dynamic> rowMap = {};

      for (int j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final value = row[j];
        rowMap[header] = _convertCsvValue(value);
      }

      if (rowMap.isNotEmpty) {
        result.add(rowMap);
      }
    }

    return result;
  } catch (e) {
    print('Error in CSV parsing: $e');
    return [];
  }
}

/// Convert CSV values to appropriate types
dynamic _convertCsvValue(dynamic value) {
  if (value == null || value == '') return '';
  
  final stringValue = value.toString().trim();
  if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') return '';
  
  // Try to parse as number
  final doubleValue = double.tryParse(stringValue);
  if (doubleValue != null) {
    // Return as int if it's a whole number, otherwise as double
    return doubleValue == doubleValue.toInt() ? doubleValue.toInt() : doubleValue;
  }
  
  return stringValue;
}

/// Process large datasets in chunks for memory efficiency
Future<Map<String, dynamic>> processLargeDatasetInChunks(Map<String, dynamic> args) async {
  final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(args['data']);
  final String operation = args['operation'];
  final Map<String, dynamic> filters = args['filters'] ?? {};
  final int chunkSize = args['chunkSize'] ?? 1000;

  final List<Map<String, dynamic>> results = [];

  try {
    switch (operation) {
      case 'filter':
        results.addAll(_filterData(data, filters));
        break;
      case 'sort':
        results.addAll(_sortData(data, filters));
        break;
      case 'aggregate':
        results.addAll(_aggregateData(data, filters));
        break;
      case 'transform':
        results.addAll(_transformData(data, filters));
        break;
      default:
        results.addAll(data); // No operation, return as is
    }
  } catch (e) {
    print('Error processing dataset chunk: $e');
    return {'results': [], 'error': e.toString()};
  }

  return {'results': results};
}

/// Filter data based on criteria
List<Map<String, dynamic>> _filterData(List<Map<String, dynamic>> data, Map<String, dynamic> filters) {
  if (filters.isEmpty) return data;

  return data.where((item) {
    for (final entry in filters.entries) {
      final key = entry.key;
      final filterValue = entry.value;
      final itemValue = item[key];

      if (filterValue is String && itemValue != null) {
        if (!itemValue.toString().toLowerCase().contains(filterValue.toLowerCase())) {
          return false;
        }
      } else if (filterValue is num && itemValue is num) {
        if (itemValue != filterValue) {
          return false;
        }
      } else if (filterValue is Map) {
        // Range filter: {'min': 0, 'max': 100}
        final min = filterValue['min'];
        final max = filterValue['max'];
        if (itemValue is num) {
          if (min != null && itemValue < min) return false;
          if (max != null && itemValue > max) return false;
        }
      }
    }
    return true;
  }).toList();
}

/// Sort data based on criteria
List<Map<String, dynamic>> _sortData(List<Map<String, dynamic>> data, Map<String, dynamic> sortCriteria) {
  final sortKey = sortCriteria['key'] as String?;
  final ascending = sortCriteria['ascending'] as bool? ?? true;

  if (sortKey == null) return data;

  final sortedData = List<Map<String, dynamic>>.from(data);
  
  sortedData.sort((a, b) {
    final aValue = a[sortKey];
    final bValue = b[sortKey];

    if (aValue == null && bValue == null) return 0;
    if (aValue == null) return ascending ? -1 : 1;
    if (bValue == null) return ascending ? 1 : -1;

    int comparison = 0;
    if (aValue is num && bValue is num) {
      comparison = aValue.compareTo(bValue);
    } else {
      comparison = aValue.toString().toLowerCase().compareTo(bValue.toString().toLowerCase());
    }

    return ascending ? comparison : -comparison;
  });

  return sortedData;
}

/// Aggregate data based on criteria
List<Map<String, dynamic>> _aggregateData(List<Map<String, dynamic>> data, Map<String, dynamic> aggregateCriteria) {
  final groupBy = aggregateCriteria['groupBy'] as String?;
  final aggregateFields = aggregateCriteria['fields'] as Map<String, String>? ?? {};

  if (groupBy == null) return data;

  final Map<String, List<Map<String, dynamic>>> groups = {};
  
  // Group data
  for (final item in data) {
    final groupValue = item[groupBy]?.toString() ?? 'null';
    groups.putIfAbsent(groupValue, () => []).add(item);
  }

  // Aggregate groups
  final List<Map<String, dynamic>> results = [];
  for (final entry in groups.entries) {
    final groupKey = entry.key;
    final groupData = entry.value;
    
    final aggregated = <String, dynamic>{groupBy: groupKey};
    
    for (final fieldEntry in aggregateFields.entries) {
      final field = fieldEntry.key;
      final operation = fieldEntry.value; // 'sum', 'avg', 'count', 'min', 'max'
      
      switch (operation.toLowerCase()) {
        case 'sum':
          aggregated[field] = groupData.fold<double>(0.0, (sum, item) {
            final value = item[field];
            return sum + (value is num ? value.toDouble() : 0.0);
          });
          break;
        case 'avg':
          final sum = groupData.fold<double>(0.0, (sum, item) {
            final value = item[field];
            return sum + (value is num ? value.toDouble() : 0.0);
          });
          aggregated[field] = groupData.isNotEmpty ? sum / groupData.length : 0.0;
          break;
        case 'count':
          aggregated[field] = groupData.length;
          break;
        case 'min':
          double? min;
          for (final item in groupData) {
            final value = item[field];
            if (value is num) {
              min = min == null ? value.toDouble() : (value.toDouble() < min ? value.toDouble() : min);
            }
          }
          aggregated[field] = min ?? 0.0;
          break;
        case 'max':
          double? max;
          for (final item in groupData) {
            final value = item[field];
            if (value is num) {
              max = max == null ? value.toDouble() : (value.toDouble() > max ? value.toDouble() : max);
            }
          }
          aggregated[field] = max ?? 0.0;
          break;
      }
    }
    
    results.add(aggregated);
  }

  return results;
}

/// Transform data based on criteria
List<Map<String, dynamic>> _transformData(List<Map<String, dynamic>> data, Map<String, dynamic> transformCriteria) {
  final transformations = transformCriteria['transformations'] as Map<String, dynamic>? ?? {};
  
  if (transformations.isEmpty) return data;

  return data.map((item) {
    final transformed = Map<String, dynamic>.from(item);
    
    for (final entry in transformations.entries) {
      final field = entry.key;
      final transformation = entry.value as Map<String, dynamic>;
      final operation = transformation['operation'] as String;
      
      switch (operation.toLowerCase()) {
        case 'multiply':
          final factor = transformation['factor'] as num? ?? 1;
          final value = item[field];
          if (value is num) {
            transformed[field] = value * factor;
          }
          break;
        case 'round':
          final decimals = transformation['decimals'] as int? ?? 0;
          final value = item[field];
          if (value is num) {
            transformed[field] = double.parse(value.toStringAsFixed(decimals));
          }
          break;
        case 'uppercase':
          final value = item[field];
          if (value != null) {
            transformed[field] = value.toString().toUpperCase();
          }
          break;
        case 'lowercase':
          final value = item[field];
          if (value != null) {
            transformed[field] = value.toString().toLowerCase();
          }
          break;
        case 'trim':
          final value = item[field];
          if (value != null) {
            transformed[field] = value.toString().trim();
          }
          break;
      }
    }
    
    return transformed;
  }).toList();
}
