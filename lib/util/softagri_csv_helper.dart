import 'package:get/get.dart';
import '../services/softagri_csv_service.dart';

/// Helper class to work with downloaded Softagri CSV data
class SoftagriCsvHelper {
  static final SoftagriCsvService _csvService = Get.find<SoftagriCsvService>();

  /// Get all sales invoice data with details
  static Map<String, dynamic>? getSalesData() {
    final masterData = _csvService.getParsedCsv('SalesInvoiceMaster.csv');
    final detailsData = _csvService.getParsedCsv('SalesInvoiceDetails.csv');
    
    if (masterData == null || detailsData == null) return null;
    
    return {
      'master': masterData,
      'details': detailsData,
      'totalInvoices': masterData.length,
      'totalLineItems': detailsData.length,
    };
  }

  /// Get all item/inventory data
  static Map<String, dynamic>? getInventoryData() {
    final itemMaster = _csvService.getParsedCsv('ItemMaster.csv');
    final itemDetail = _csvService.getParsedCsv('ItemDetail.csv');
    
    if (itemMaster == null || itemDetail == null) return null;
    
    return {
      'master': itemMaster,
      'details': itemDetail,
      'totalItems': itemMaster.length,
      'totalDetails': itemDetail.length,
    };
  }

  /// Get all account data
  static Map<String, dynamic>? getAccountData() {
    final accountMaster = _csvService.getParsedCsv('AccountMaster.csv');
    final allAccounts = _csvService.getParsedCsv('AllAccounts.csv');
    
    if (accountMaster == null || allAccounts == null) return null;
    
    return {
      'master': accountMaster,
      'all': allAccounts,
      'totalMasterAccounts': accountMaster.length,
      'totalAllAccounts': allAccounts.length,
    };
  }

  /// Get customer information
  static List<Map<String, dynamic>>? getCustomers() {
    return _csvService.getParsedCsv('CustomerInformation.csv');
  }

  /// Get supplier information
  static List<Map<String, dynamic>>? getSuppliers() {
    return _csvService.getParsedCsv('SupplierInformation.csv');
  }

  /// Get self/company information
  static List<Map<String, dynamic>>? getCompanyInfo() {
    return _csvService.getParsedCsv('selfinformation.csv');
  }

  /// Get summary of all downloaded data
  static Map<String, dynamic> getDataSummary() {
    final Map<String, dynamic> summary = {
      'downloadedFiles': [],
      'totalRecords': 0,
      'dataTypes': {},
    };

    for (final fileName in SoftagriCsvService.requiredCsvFiles) {
      final data = _csvService.getParsedCsv(fileName);
      if (data != null) {
        summary['downloadedFiles'].add(fileName);
        summary['totalRecords'] += data.length;
        summary['dataTypes'][fileName] = data.length;
      }
    }

    return summary;
  }

  /// Search for items by name or code
  static List<Map<String, dynamic>> searchItems(String query) {
    final itemMaster = _csvService.getParsedCsv('ItemMaster.csv');
    if (itemMaster == null) return [];
    
    return itemMaster.where((item) {
      final itemName = item['ItemName']?.toString().toLowerCase() ?? '';
      final itemCode = item['ItemCode']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      
      return itemName.contains(searchQuery) || itemCode.contains(searchQuery);
    }).toList();
  }

  /// Search for customers by name
  static List<Map<String, dynamic>> searchCustomers(String query) {
    final customers = _csvService.getParsedCsv('CustomerInformation.csv');
    if (customers == null) return [];
    
    return customers.where((customer) {
      final customerName = customer['CustomerName']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      
      return customerName.contains(searchQuery);
    }).toList();
  }

  /// Get sales data for a specific customer
  static Map<String, dynamic>? getCustomerSales(String customerId) {
    final salesMaster = _csvService.getParsedCsv('SalesInvoiceMaster.csv');
    final salesDetails = _csvService.getParsedCsv('SalesInvoiceDetails.csv');
    
    if (salesMaster == null || salesDetails == null) return null;
    
    final customerInvoices = salesMaster.where((invoice) {
      return invoice['CustomerId']?.toString() == customerId;
    }).toList();
    
    final invoiceIds = customerInvoices.map((invoice) => invoice['InvoiceId']?.toString()).toList();
    
    final customerSalesDetails = salesDetails.where((detail) {
      return invoiceIds.contains(detail['InvoiceId']?.toString());
    }).toList();
    
    return {
      'invoices': customerInvoices,
      'details': customerSalesDetails,
      'totalInvoices': customerInvoices.length,
      'totalItems': customerSalesDetails.length,
    };
  }

  /// Calculate total sales amount
  static double calculateTotalSales() {
    final salesMaster = _csvService.getParsedCsv('SalesInvoiceMaster.csv');
    if (salesMaster == null) return 0.0;
    
    double total = 0.0;
    for (final invoice in salesMaster) {
      final amount = double.tryParse(invoice['TotalAmount']?.toString() ?? '0') ?? 0.0;
      total += amount;
    }
    
    return total;
  }

  /// Get top-selling items
  static List<Map<String, dynamic>> getTopSellingItems({int limit = 10}) {
    final salesDetails = _csvService.getParsedCsv('SalesInvoiceDetails.csv');
    if (salesDetails == null) return [];
    
    final Map<String, double> itemQuantities = {};
    
    for (final detail in salesDetails) {
      final itemId = detail['ItemId']?.toString() ?? '';
      final quantity = double.tryParse(detail['Quantity']?.toString() ?? '0') ?? 0.0;
      
      itemQuantities[itemId] = (itemQuantities[itemId] ?? 0.0) + quantity;
    }
    
    final sortedItems = itemQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedItems.take(limit).map((entry) => {
      'itemId': entry.key,
      'totalQuantity': entry.value,
    }).toList();
  }

  /// Check if all required data is available
  static bool isAllDataAvailable() {
    for (final fileName in SoftagriCsvService.requiredCsvFiles) {
      if (_csvService.getParsedCsv(fileName) == null) {
        return false;
      }
    }
    return true;
  }

  /// Get missing files list
  static List<String> getMissingFiles() {
    final List<String> missing = [];
    
    for (final fileName in SoftagriCsvService.requiredCsvFiles) {
      if (_csvService.getParsedCsv(fileName) == null) {
        missing.add(fileName);
      }
    }
    
    return missing;
  }

  /// Export specific data type to Map for easy use
  static Map<String, dynamic>? exportDataAsMap(String fileName) {
    final data = _csvService.getParsedCsv(fileName);
    if (data == null) return null;
    
    return {
      'fileName': fileName,
      'recordCount': data.length,
      'data': data,
      'columns': data.isNotEmpty ? data.first.keys.toList() : [],
    };
  }

  /// Get data validation summary
  static Map<String, dynamic> getDataValidation() {
    final Map<String, dynamic> validation = {
      'isValid': true,
      'errors': <String>[],
      'warnings': <String>[],
      'fileStatus': <String, String>{},
    };

    for (final fileName in SoftagriCsvService.requiredCsvFiles) {
      final data = _csvService.getParsedCsv(fileName);
      
      if (data == null) {
        validation['isValid'] = false;
        validation['errors'].add('Missing file: $fileName');
        validation['fileStatus'][fileName] = 'missing';
      } else if (data.isEmpty) {
        validation['warnings'].add('Empty file: $fileName');
        validation['fileStatus'][fileName] = 'empty';
      } else {
        validation['fileStatus'][fileName] = 'valid';
      }
    }

    return validation;
  }
}