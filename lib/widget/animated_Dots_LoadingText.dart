import 'dart:math';

import 'package:flutter/cupertino.dart';

class DotsWaveLoadingText extends StatefulWidget {
  final Color? color;
  const DotsWaveLoadingText({super.key, this.color,});

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
