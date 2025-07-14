import 'package:intl/intl.dart';

Map<String, dynamic> lowerMap(Map<String, dynamic> src) => {
  for (final e in src.entries)
    e.key.toString().toLowerCase().trim(): e.value,
};

DateTime parseFlexibleDate(dynamic s) {
  if (s is DateTime) return s;
  final str = s.toString().trim();

  // ISO‑8601 like 2024‑05‑17 or 2024‑05‑17T10:15:00
  final iso = DateTime.tryParse(str);
  if (iso != null) return iso;

  // Common dd/MM/yyyy
  try {
    return DateFormat('dd/MM/yyyy').parse(str);
  } catch (_) {}

  // Fallback
  return DateTime.now();
}
