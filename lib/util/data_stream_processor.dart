// lib/util/data_stream_processor.dart

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// Stream processor for handling very large datasets without loading everything into memory
class DataStreamProcessor {
  static const int _defaultChunkSize = 1000;
  static const int _maxMemoryBufferMB = 50;

  /// Process large CSV data as a stream
  static Stream<List<Map<String, dynamic>>> processCSVStream({
    required String csvData,
    int chunkSize = _defaultChunkSize,
    List<String>? stringColumns,
    Function(double)? onProgress,
  }) async* {
    if (csvData.isEmpty) return;

    final lines = csvData.split('\n');
    if (lines.isEmpty) return;

    final cleanLines = lines.where((line) => line.trim().isNotEmpty).toList();
    if (cleanLines.isEmpty) return;

    // Parse header
    final headerLine = cleanLines.first;
    final headers = _parseCSVLine(headerLine);
    
    int processedLines = 0;
    final totalLines = cleanLines.length - 1; // Exclude header

    // Process data in chunks
    for (int i = 1; i < cleanLines.length; i += chunkSize) {
      final chunkLines = cleanLines.skip(i).take(chunkSize).toList();
      final chunk = await _processChunkInIsolate(chunkLines, headers, stringColumns ?? []);
      
      if (chunk.isNotEmpty) {
        yield chunk;
      }

      processedLines += chunkLines.length;
      final progress = processedLines / totalLines;
      onProgress?.call(progress.clamp(0.0, 1.0));

      // Allow other operations to proceed
      await Future.delayed(Duration(milliseconds: 10));
    }
  }

  /// Process a chunk of CSV lines in an isolate
  static Future<List<Map<String, dynamic>>> _processChunkInIsolate(
    List<String> lines,
    List<String> headers,
    List<String> stringColumns,
  ) async {
    return await compute(_processChunk, {
      'lines': lines,
      'headers': headers,
      'stringColumns': stringColumns,
    });
  }

  /// Process chunk in isolate
  static List<Map<String, dynamic>> _processChunk(Map<String, dynamic> args) {
    final lines = args['lines'] as List<String>;
    final headers = args['headers'] as List<String>;
    final stringColumns = Set<String>.from(args['stringColumns'] as List<String>);

    final List<Map<String, dynamic>> result = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final values = _parseCSVLine(line);
      final Map<String, dynamic> row = {};

      for (int j = 0; j < headers.length && j < values.length; j++) {
        final header = headers[j];
        final value = values[j];
        
        if (stringColumns.contains(header)) {
          row[header] = value.toString().trim();
        } else {
          row[header] = _convertValue(value);
        }
      }

      if (row.isNotEmpty) {
        result.add(row);
      }
    }

    return result;
  }

  /// Parse a single CSV line handling quoted values
  static List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escapeNext = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (escapeNext) {
        buffer.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    result.add(buffer.toString().trim());
    return result;
  }

  /// Convert value to appropriate type
  static dynamic _convertValue(dynamic value) {
    if (value == null || value == '') return '';
    
    final stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') return '';
    
    // Try to parse as number
    final doubleValue = double.tryParse(stringValue);
    if (doubleValue != null) {
      return doubleValue == doubleValue.toInt() ? doubleValue.toInt() : doubleValue;
    }
    
    return stringValue;
  }

  /// Filter stream data based on criteria
  static Stream<List<Map<String, dynamic>>> filterStream(
    Stream<List<Map<String, dynamic>>> inputStream,
    Map<String, dynamic> filters,
  ) async* {
    await for (final chunk in inputStream) {
      final filtered = chunk.where((item) {
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
            // Range filter
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

      if (filtered.isNotEmpty) {
        yield filtered;
      }
    }
  }

  /// Transform stream data
  static Stream<List<Map<String, dynamic>>> transformStream(
    Stream<List<Map<String, dynamic>>> inputStream,
    Map<String, Function(dynamic)> transformers,
  ) async* {
    await for (final chunk in inputStream) {
      final transformed = chunk.map((item) {
        final result = Map<String, dynamic>.from(item);
        
        for (final entry in transformers.entries) {
          final key = entry.key;
          final transformer = entry.value;
          
          if (result.containsKey(key)) {
            try {
              result[key] = transformer(result[key]);
            } catch (e) {
              // Keep original value if transformation fails
              continue;
            }
          }
        }
        
        return result;
      }).toList();

      yield transformed;
    }
  }

  /// Aggregate stream data
  static Future<Map<String, dynamic>> aggregateStream(
    Stream<List<Map<String, dynamic>>> inputStream,
    String groupByField,
    Map<String, String> aggregateFields, // field -> operation (sum, avg, count, min, max)
  ) async {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    
    await for (final chunk in inputStream) {
      for (final item in chunk) {
        final groupValue = item[groupByField]?.toString() ?? 'null';
        groups.putIfAbsent(groupValue, () => []).add(item);
      }
    }

    final Map<String, dynamic> results = {};
    
    for (final entry in groups.entries) {
      final groupKey = entry.key;
      final groupData = entry.value;
      
      final aggregated = <String, dynamic>{groupByField: groupKey};
      
      for (final fieldEntry in aggregateFields.entries) {
        final field = fieldEntry.key;
        final operation = fieldEntry.value.toLowerCase();
        
        switch (operation) {
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
      
      results[groupKey] = aggregated;
    }

    return results;
  }

  /// Collect stream into pages for pagination
  static Future<List<List<Map<String, dynamic>>>> collectPages(
    Stream<List<Map<String, dynamic>>> inputStream,
    int pageSize,
  ) async {
    final List<List<Map<String, dynamic>>> pages = [];
    List<Map<String, dynamic>> currentPage = [];

    await for (final chunk in inputStream) {
      for (final item in chunk) {
        currentPage.add(item);
        
        if (currentPage.length >= pageSize) {
          pages.add(List.from(currentPage));
          currentPage.clear();
        }
      }
    }

    // Add remaining items as the last page
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  /// Get stream statistics without loading all data
  static Future<Map<String, dynamic>> getStreamStats(
    Stream<List<Map<String, dynamic>>> inputStream,
  ) async {
    int totalCount = 0;
    final Map<String, int> fieldCounts = {};
    final Map<String, Set<dynamic>> uniqueValues = {};
    
    await for (final chunk in inputStream) {
      totalCount += chunk.length;
      
      for (final item in chunk) {
        for (final entry in item.entries) {
          final key = entry.key;
          final value = entry.value;
          
          fieldCounts[key] = (fieldCounts[key] ?? 0) + 1;
          
          // Track unique values for small sets
          uniqueValues.putIfAbsent(key, () => <dynamic>{});
          if (uniqueValues[key]!.length < 100) { // Limit to prevent memory issues
            uniqueValues[key]!.add(value);
          }
        }
      }
    }

    return {
      'totalCount': totalCount,
      'fieldCounts': fieldCounts,
      'uniqueValueCounts': uniqueValues.map(
        (key, values) => MapEntry(key, values.length),
      ),
    };
  }

  /// Memory-efficient search through stream
  static Stream<Map<String, dynamic>> searchStream(
    Stream<List<Map<String, dynamic>>> inputStream,
    String searchTerm,
    List<String> searchFields,
  ) async* {
    final lowerSearchTerm = searchTerm.toLowerCase();
    
    await for (final chunk in inputStream) {
      for (final item in chunk) {
        bool matches = false;
        
        for (final field in searchFields) {
          final value = item[field];
          if (value != null && 
              value.toString().toLowerCase().contains(lowerSearchTerm)) {
            matches = true;
            break;
          }
        }
        
        if (matches) {
          yield item;
        }
      }
    }
  }
}