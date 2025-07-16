class ItemMasterRow {
  final int    itemCode;
  final String itemName;

  ItemMasterRow({
    required this.itemCode,
    required this.itemName,
  });

  factory ItemMasterRow.fromCsv(Map<String, dynamic> r) {
    return ItemMasterRow(
      itemCode : int.tryParse(r['itemcode']?.toString() ?? '') ?? 0,
      itemName : r['itemname']?.toString() ?? '',
    );
  }
}
