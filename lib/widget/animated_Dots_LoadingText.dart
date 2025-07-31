import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DotsWaveLoadingText extends StatefulWidget {
  final Color? color;

  final dynamic text;
  const DotsWaveLoadingText({super.key, this.color, this.text,});

  @override
  State<DotsWaveLoadingText> createState() => _DotsWaveLoadingTextState();
}

class _DotsWaveLoadingTextState extends State<DotsWaveLoadingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final double value = sin((_controller.value * 2 * pi) + delay);
        return Transform.translate(
          offset: Offset(0, -8 * value.abs()),
          child: const Text(
            '.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Fetching Data ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        _buildDot(0.0),
        _buildDot(0.5),
        _buildDot(1.0),

      ],
    );
  }
}
class ProgressLoadingWidget extends StatelessWidget {
  final double progress;
  final String message;
  final Color? color;

  const ProgressLoadingWidget({
    Key? key,
    required this.progress,
    required this.message,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).primaryColor;
    final surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: surfaceVariantColor,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurfaceColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: onSurfaceColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: surfaceVariantColor,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ],
      ),
    );
  }
}