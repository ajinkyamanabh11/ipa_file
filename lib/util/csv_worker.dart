// lib/util/csv_worker.dart
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

// Enhanced CSV processing with progress tracking
Future<Map<String, dynamic>> parseAndCacheCsv(Map<String, dynamic> args) async {
  final String key = args['key'];
  final String csvData = args['csvData'];
  final int chunkSize = args['chunkSize'] ?? 1000;
  final SendPort? progressPort = args['progressPort'];

  final double estimatedSizeMB = (csvData.length * 2) / (1024 * 1024);
  
  // Process in chunks to avoid blocking
  final lines = csvData.split('\n');
  final totalLines = lines.length;
  
  if (progressPort != null) {
    progressPort.send({
      'type': 'progress',
      'key': key,
      'current': 0,
      'total': totalLines,
      'message': 'Starting CSV processing...'
    });
  }

  // Process in chunks
  String processedData = '';
  for (int i = 0; i < lines.length; i += chunkSize) {
    final end = (i + chunkSize < lines.length) ? i + chunkSize : lines.length;
    final chunk = lines.sublist(i, end);
    processedData += chunk.join('\n') + '\n';
    
    // Send progress update every 10% or every 1000 lines
    if (progressPort != null && (i % (totalLines ~/ 10) == 0 || i % 1000 == 0)) {
      progressPort.send({
        'type': 'progress',
        'key': key,
        'current': i,
        'total': totalLines,
        'message': 'Processing line ${i + 1} of $totalLines'
      });
    }
    
    // Small delay to prevent blocking
    if (i % (chunkSize * 5) == 0) {
      await Future.delayed(Duration(milliseconds: 1));
    }
  }

  if (progressPort != null) {
    progressPort.send({
      'type': 'progress',
      'key': key,
      'current': totalLines,
      'total': totalLines,
      'message': 'CSV processing completed'
    });
  }

  return {
    'key': key,
    'csvData': processedData,
    'estimatedSizeMB': estimatedSizeMB,
    'totalLines': totalLines,
  };
}

// Batch CSV processing for multiple files
Future<Map<String, dynamic>> processMultipleCsvs(Map<String, dynamic> args) async {
  final List<Map<String, dynamic>> csvConfigs = args['csvConfigs'];
  final SendPort? progressPort = args['progressPort'];
  
  final results = <String, dynamic>{};
  
  for (int i = 0; i < csvConfigs.length; i++) {
    final config = csvConfigs[i];
    
    if (progressPort != null) {
      progressPort.send({
        'type': 'file_progress',
        'current_file': i + 1,
        'total_files': csvConfigs.length,
        'filename': config['filename'],
        'message': 'Processing ${config['filename']}...'
      });
    }
    
    final result = await parseAndCacheCsv({
      'key': config['key'],
      'csvData': config['csvData'],
      'chunkSize': config['chunkSize'] ?? 1000,
      'progressPort': progressPort,
    });
    
    results[config['key']] = result;
    
    // Small delay between files
    await Future.delayed(Duration(milliseconds: 50));
  }
  
  return results;
}
