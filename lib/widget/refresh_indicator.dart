import "package:flutter/material.dart";

class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color color;
  final Color? backgroundColor;
  final double edgeOffset;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = Colors.green,
    this.backgroundColor,
    this.edgeOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(

      onRefresh: onRefresh,
      color: color,
      backgroundColor: backgroundColor,
      edgeOffset: edgeOffset,
      child: child,
    );
  }
}
