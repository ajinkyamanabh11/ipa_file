import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/data_loading_service.dart';
import '../services/CsvDataServices.dart';
import '../util/memory_monitor.dart';
import 'loading_widget.dart';

class DataLoadingExample extends StatelessWidget {
  const DataLoadingExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataLoadingService dataLoadingService = Get.find<DataLoadingService>();
    final CsvDataService csvDataService = Get.find<CsvDataService>();
    final MemoryMonitor memoryMonitor = Get.find<MemoryMonitor>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Loading Example'),
        actions: [
          // Memory status indicator
          Obx(() => Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  memoryMonitor.isMemoryCritical.value 
                    ? Icons.memory 
                    : memoryMonitor.isMemoryWarning.value 
                      ? Icons.warning 
                      : Icons.check_circle,
                  color: memoryMonitor.isMemoryCritical.value 
                    ? Colors.red 
                    : memoryMonitor.isMemoryWarning.value 
                      ? Colors.orange 
                      : Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  memoryMonitor.memoryStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: memoryMonitor.isMemoryCritical.value 
                      ? Colors.red 
                      : memoryMonitor.isMemoryWarning.value 
                        ? Colors.orange 
                        : Colors.green,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
      body: DataLoadingWidget(
        csvDataService: csvDataService,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Data loading status
              Obx(() {
                if (dataLoadingService.isLoading) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            dataLoadingService.loadingMessage,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: dataLoadingService.loadingProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(dataLoadingService.loadingProgress * 100).toInt()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: 16),

              // Control buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: dataLoadingService.isLoading 
                        ? null 
                        : () => dataLoadingService.initializeData(),
                      icon: const Icon(Icons.download),
                      label: const Text('Load Data'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: dataLoadingService.isLoading 
                        ? null 
                        : () => dataLoadingService.refreshAllData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Memory management buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => memoryMonitor.requestCleanup(),
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Clean Memory'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => dataLoadingService.clearAllCache(),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Cache'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Data status
              Obx(() => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow('Data Ready', dataLoadingService.isDataReady.value),
                      _buildStatusRow('Memory Usage', '${memoryMonitor.currentMemoryUsageMB.value.toStringAsFixed(1)}MB'),
                      _buildStatusRow('Can Perform Heavy Operations', memoryMonitor.canPerformHeavyOperation),
                      if (memoryMonitor.isMemoryWarning.value)
                        _buildStatusRow('Memory Warning', '⚠️ High memory usage', isWarning: true),
                      if (memoryMonitor.isMemoryCritical.value)
                        _buildStatusRow('Memory Critical', '🚨 Critical memory usage', isError: true),
                    ],
                  ),
                ),
              )),

              const SizedBox(height: 16),

              // CSV Data status
              Obx(() => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Data Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow('Sales Master', csvDataService.salesMasterCsv.value.isNotEmpty),
                      _buildStatusRow('Sales Details', csvDataService.salesDetailsCsv.value.isNotEmpty),
                      _buildStatusRow('Item Master', csvDataService.itemMasterCsv.value.isNotEmpty),
                      _buildStatusRow('Item Details', csvDataService.itemDetailCsv.value.isNotEmpty),
                      _buildStatusRow('Account Master', csvDataService.accountMasterCsv.value.isNotEmpty),
                      _buildStatusRow('All Accounts', csvDataService.allAccountsCsv.value.isNotEmpty),
                      _buildStatusRow('Customer Info', csvDataService.customerInfoCsv.value.isNotEmpty),
                      _buildStatusRow('Supplier Info', csvDataService.supplierInfoCsv.value.isNotEmpty),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value, {bool isWarning = false, bool isError = false}) {
    Color textColor = Colors.black87;
    if (isError) textColor = Colors.red;
    else if (isWarning) textColor = Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: textColor),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}