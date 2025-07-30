import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/CsvDataServices.dart';
import '../services/background_processor.dart';
import '../util/memory_monitor.dart';

/// Performance monitoring widget to display real-time app metrics
class PerformanceMonitorWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;

  const PerformanceMonitorWidget({
    Key? key,
    this.isExpanded = false,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Performance Monitor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: onToggle,
            ),
          ),
          if (isExpanded) ...[
            Divider(),
            _buildMetrics(),
          ],
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCsvServiceMetrics(),
          SizedBox(height: 16),
          _buildBackgroundProcessorMetrics(),
          SizedBox(height: 16),
          _buildMemoryMetrics(),
          SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCsvServiceMetrics() {
    return GetBuilder<CsvDataService>(
      builder: (csvService) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV Data Service',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Memory Usage',
                    value: '${csvService.memoryUsageMB.value.toStringAsFixed(1)} MB',
                    color: csvService.memoryUsageMB.value > 80 ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Loading Progress',
                    value: '${(csvService.loadingProgress.value * 100).toStringAsFixed(1)}%',
                    color: csvService.loadingProgress.value == 1.0 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _StatusIndicator(
                  label: 'Critical Loading',
                  isActive: csvService.isLoadingCritical.value,
                ),
                SizedBox(width: 16),
                _StatusIndicator(
                  label: 'Secondary Loading',
                  isActive: csvService.isLoadingSecondary.value,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundProcessorMetrics() {
    return GetBuilder<BackgroundProcessor>(
      builder: (processor) {
        final stats = processor.getStats();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Processor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Queue Length',
                    value: '${stats['queueLength']}',
                    color: stats['queueLength'] > 5 ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Active Tasks',
                    value: '${stats['activeTasks']}',
                    color: stats['activeTasks'] > 2 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (stats['isProcessing'])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Task: ${stats['currentTask']}'),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: stats['progress'].toDouble(),
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildMemoryMetrics() {
    return GetBuilder<MemoryMonitor>(
      builder: (monitor) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Monitor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Current Usage',
                    value: '${monitor.currentUsageMB.value.toStringAsFixed(1)} MB',
                    color: monitor.currentUsageMB.value > 100 ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Peak Usage',
                    value: '${monitor.peakUsageMB.value.toStringAsFixed(1)} MB',
                    color: monitor.peakUsageMB.value > 150 ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _StatusIndicator(
              label: 'High Memory Warning',
              isActive: monitor.isHighMemoryUsage.value,
              activeColor: Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Get.find<CsvDataService>().getCurrentMemoryUsageMB();
              Get.find<BackgroundProcessor>().optimizeMemory();
              Get.snackbar(
                'Memory Optimization',
                'Memory cleanup performed',
                duration: Duration(seconds: 2),
              );
            },
            child: Text('Optimize Memory'),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Get.find<CsvDataService>().clearParsedCache();
              Get.snackbar(
                'Cache Cleared',
                'Parsed data cache cleared',
                duration: Duration(seconds: 2),
              );
            },
            child: Text('Clear Cache'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? activeColor;

  const _StatusIndicator({
    required this.label,
    required this.isActive,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? Colors.green) : Colors.grey;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Performance monitor overlay for development
class PerformanceOverlay extends StatefulWidget {
  final Widget child;

  const PerformanceOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _PerformanceOverlayState createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  bool _isVisible = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: PerformanceMonitorWidget(
              isExpanded: _isExpanded,
              onToggle: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
        Positioned(
          top: 50,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _isVisible = !_isVisible),
            child: Icon(_isVisible ? Icons.close : Icons.analytics),
            tooltip: 'Toggle Performance Monitor',
          ),
        ),
      ],
    );
  }
}