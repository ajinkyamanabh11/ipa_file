import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/CsvDataServices.dart';

class DataLoadingWidget extends StatelessWidget {
  final CsvDataService csvDataService;
  final Widget child;
  final bool showOverlay;

  const DataLoadingWidget({
    Key? key,
    required this.csvDataService,
    required this.child,
    this.showOverlay = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showOverlay)
          Obx(() {
            if (!csvDataService.isLoading.value) {
              return const SizedBox.shrink();
            }

            return Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          csvDataService.loadingMessage.value,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (csvDataService.totalFiles.value > 0)
                          Text(
                            'File ${csvDataService.currentFileIndex.value} of ${csvDataService.totalFiles.value}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (csvDataService.loadingProgress.value > 0)
                          LinearProgressIndicator(
                            value: csvDataService.loadingProgress.value,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (csvDataService.loadingProgress.value > 0)
                          Text(
                            '${(csvDataService.loadingProgress.value * 100).toInt()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (csvDataService.isMemoryWarning.value)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.orange[800], size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'High memory usage',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final double progress;
  final Widget child;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.message,
    this.progress = 0.0,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (progress > 0) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}