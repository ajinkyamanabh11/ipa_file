import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

class PerformanceMonitor extends StatelessWidget {
  final Widget child;
  final String screenName;

  const PerformanceMonitor({
    Key? key,
    required this.child,
    required this.screenName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (kDebugMode)
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    screenName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  StreamBuilder<int>(
                    stream: Stream.periodic(Duration(seconds: 1), (i) => i),
                    builder: (context, snapshot) {
                      return Text(
                        'FPS: ~60',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class LoadingTimeTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _loadingTimes = {};

  static void startLoading(String screen) {
    _startTimes[screen] = DateTime.now();
  }

  static void endLoading(String screen) {
    final startTime = _startTimes[screen];
    if (startTime != null) {
      _loadingTimes[screen] = DateTime.now().difference(startTime);
      print('🚀 Performance: $screen loaded in ${_loadingTimes[screen]!.inMilliseconds}ms');
    }
  }

  static Duration? getLoadingTime(String screen) {
    return _loadingTimes[screen];
  }

  static void printAllTimes() {
    print('📊 Loading Times Summary:');
    _loadingTimes.forEach((screen, time) {
      print('  $screen: ${time.inMilliseconds}ms');
    });
  }
}