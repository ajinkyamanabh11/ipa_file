import 'package:csv/csv.dart';

class CsvUtils {
  static List<Map<String, dynamic>> toMaps(
      String raw, {
        bool parseNumbers = true,
      }) {
    final table = CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: parseNumbers,
    ).convert(raw);

    final header = table.first.map((e) => e.toString()).toList();
    return table.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < header.length && i < row.length; i++) {
        map[header[i]] = row[i];
        map[header[i].toLowerCase()] = row[i]; // convenience key
      }
      return map;
    }).toList();
  }
}
