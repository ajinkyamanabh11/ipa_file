// lib/widget/progressive_loader.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/background_processor.dart';

/// A widget that shows progressive loading with smooth animations
class ProgressiveLoader extends StatelessWidget {
  final Widget child;
  final String? loadingMessage;
  final bool showProgress;
  final bool showQueue;
  final Color? progressColor;
  final Color? backgroundColor;

  const ProgressiveLoader({
    Key? key,
    required this.child,
    this.loadingMessage,
    this.showProgress = true,
    this.showQueue = false,
    this.progressColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundProcessor = Get.find<BackgroundProcessor>();

    return Stack(
      children: [
        child,
        Obx(() {
          if (!backgroundProcessor.isProcessing.value) {
            return const SizedBox.shrink();
          }

          return Container(
            color: backgroundColor ?? Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: showProgress ? backgroundProcessor.progress.value : null,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor ?? Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loadingMessage ?? backgroundProcessor.currentTask.value,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (showProgress) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(backgroundProcessor.progress.value * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (showQueue && backgroundProcessor.queueLength.value > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Queue: ${backgroundProcessor.queueLength.value} tasks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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

/// A shimmer loading effect for list items
class ShimmerListLoader extends StatefulWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;

  const ShimmerListLoader({
    Key? key,
    this.itemCount = 5,
    this.itemHeight = 80.0,
    this.padding,
  }) : super(key: key);

  @override
  State<ShimmerListLoader> createState() => _ShimmerListLoaderState();
}

class _ShimmerListLoaderState extends State<ShimmerListLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              height: widget.itemHeight,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      _buildShimmerBox(50, 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildShimmerBox(double.infinity, 16),
                            const SizedBox(height: 8),
                            _buildShimmerBox(200, 12),
                            const SizedBox(height: 4),
                            _buildShimmerBox(150, 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: [
            (_animation.value - 1).clamp(0.0, 1.0),
            _animation.value.clamp(0.0, 1.0),
            (_animation.value + 1).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

/// A loading overlay that can be used anywhere in the app
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final double? progress;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.message,
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          message!,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(progress! * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium,
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

/// A smart data loader that handles different loading states
class SmartDataLoader<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  final String? loadingMessage;
  final bool showProgress;

  const SmartDataLoader({
    Key? key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.loadingMessage,
    this.showProgress = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              (showProgress ?
              ProgressiveLoader(
                child: const SizedBox.shrink(),
                loadingMessage: loadingMessage,
              ) :
              const Center(child: CircularProgressIndicator())
              );
        }

        if (snapshot.hasError) {
          return errorBuilder?.call(snapshot.error.toString()) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading data',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
        }

        if (snapshot.hasData) {
          return builder(snapshot.data!);
        }

        return const Center(child: Text('No data available'));
      },
    );
  }
}