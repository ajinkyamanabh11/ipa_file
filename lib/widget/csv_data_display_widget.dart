import 'package:flutter/material.dart';
import '../services/automated_csv_service.dart';

class CsvDataDisplayWidget extends StatelessWidget {
  final CsvFileInfo csvFile;
  final int maxRows;
  final bool showHeaders;

  const CsvDataDisplayWidget({
    super.key,
    required this.csvFile,
    this.maxRows = 10,
    this.showHeaders = true,
  });

  @override
  Widget build(BuildContext context) {
    if (csvFile.content == null || csvFile.content!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Download the file to view its contents',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lines = csvFile.content!.split('\n');
    if (lines.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Empty CSV file'),
        ),
      );
    }

    // Parse CSV headers
    final headers = _parseCsvLine(lines.first);
    final dataRows = lines.skip(showHeaders ? 1 : 0).take(maxRows).toList();

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.table_chart, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    csvFile.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                if (csvFile.size != null)
                  Text(
                    csvFile.size!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: showHeaders ? 32 : 0,
              dataRowHeight: 28,
              columnSpacing: 12,
              horizontalMargin: 12,
              columns: headers.map((header) => DataColumn(
                label: showHeaders ? Text(
                  header.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ) : const Text(''),
              )).toList(),
              rows: dataRows
                  .where((line) => line.trim().isNotEmpty)
                  .map((line) {
                final cells = _parseCsvLine(line);
                return DataRow(
                  cells: List.generate(headers.length, (index) {
                    final cellValue = index < cells.length ? cells[index].trim() : '';
                    return DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          cellValue,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                );
              }).toList(),
            ),
          ),
          
          // Footer info
          if (lines.length > maxRows + (showHeaders ? 1 : 0))
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Showing ${maxRows} of ${lines.length - (showHeaders ? 1 : 0)} rows',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _parseCsvLine(String line) {
    // Simple CSV parser - handles basic comma separation
    // For more complex CSV parsing, consider using a proper CSV library
    final result = <String>[];
    bool inQuotes = false;
    String current = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    result.add(current);
    
    return result;
  }
}