// lib/Screens/example_lazy_loading_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer';
import '../controllers/sales_controller.dart';
import '../controllers/customerLedger_Controller.dart';
import '../services/lazy_data_service.dart';

/// Example screen demonstrating lazy loading implementation
/// This screen shows how to properly load data on demand
class ExampleLazyLoadingScreen extends StatefulWidget {
  const ExampleLazyLoadingScreen({super.key});

  @override
  State<ExampleLazyLoadingScreen> createState() => _ExampleLazyLoadingScreenState();
}

class _ExampleLazyLoadingScreenState extends State<ExampleLazyLoadingScreen> {
  final SalesController _salesController = Get.find<SalesController>();
  final CustomerLedgerController _ledgerController = Get.find<CustomerLedgerController>();
  final LazyDataService _lazyDataService = Get.find<LazyDataService>();

  @override
  void initState() {
    super.initState();
    // Don't load data automatically - wait for user interaction
    log('ExampleLazyLoadingScreen: Initialized - no data loaded yet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lazy Loading Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Memory usage indicator
            _buildMemoryUsageCard(),
            const SizedBox(height: 16),
            
            // Data loading buttons
            _buildDataLoadingSection(),
            const SizedBox(height: 16),
            
            // Sales data section
            _buildSalesSection(),
            const SizedBox(height: 16),
            
            // Customer ledger section
            _buildLedgerSection(),
            const SizedBox(height: 16),
            
            // Memory management buttons
            _buildMemoryManagementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryUsageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Usage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Obx(() {
              final usage = _lazyDataService.getCurrentMemoryUsageMB();
              final isWarning = _lazyDataService.isMemoryWarning.value;
              
              return Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: usage / 100.0, // Assuming 100MB max
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isWarning ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${usage.toStringAsFixed(1)} MB',
                    style: TextStyle(
                      color: isWarning ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
            if (_lazyDataService.isMemoryWarning.value)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ High memory usage detected',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataLoadingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Load Data On Demand',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadSalesData(),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Load Sales'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _loadLedgerData(),
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Load Ledger'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _loadAllData(),
                  icon: const Icon(Icons.download),
                  label: const Text('Load All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Obx(() {
                  if (_salesController.isLoading.value) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (_salesController.error.value != null) {
                return Text(
                  'Error: ${_salesController.error.value}',
                  style: TextStyle(color: Colors.red[700]),
                );
              }
              
              return Text(
                'Sales entries: ${_salesController.sales.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }),
            if (_salesController.sales.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  itemCount: _salesController.sales.take(3).length,
                  itemBuilder: (context, index) {
                    final sale = _salesController.sales[index];
                    return ListTile(
                      dense: true,
                      title: Text(sale.accountName),
                      subtitle: Text(sale.billNo),
                      trailing: Text('₹${sale.amount.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Ledger',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Obx(() {
                  if (_ledgerController.isLoading.value) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (_ledgerController.error.value != null) {
                return Text(
                  'Error: ${_ledgerController.error.value}',
                  style: TextStyle(color: Colors.red[700]),
                );
              }
              
              return Text(
                'Accounts: ${_ledgerController.accounts.length}, Transactions: ${_ledgerController.transactions.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _clearSalesData(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Sales'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _clearAllData(),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Data loading methods
  Future<void> _loadSalesData() async {
    try {
      log('Loading sales data...');
      await _salesController.fetchSales();
      log('Sales data loaded successfully');
    } catch (e) {
      log('Error loading sales data: $e');
    }
  }

  Future<void> _loadLedgerData() async {
    try {
      log('Loading ledger data...');
      await _ledgerController.loadData();
      log('Ledger data loaded successfully');
    } catch (e) {
      log('Error loading ledger data: $e');
    }
  }

  Future<void> _loadAllData() async {
    try {
      log('Loading all data...');
      await Future.wait([
        _loadSalesData(),
        _loadLedgerData(),
      ]);
      log('All data loaded successfully');
    } catch (e) {
      log('Error loading all data: $e');
    }
  }

  // Memory management methods
  void _clearSalesData() {
    _lazyDataService.clearData('sales');
    _salesController.sales.clear();
    log('Sales data cleared from memory');
  }

  void _clearAllData() {
    _lazyDataService.clearAllData();
    _salesController.sales.clear();
    _ledgerController.accounts.clear();
    _ledgerController.transactions.clear();
    log('All data cleared from memory');
  }
}