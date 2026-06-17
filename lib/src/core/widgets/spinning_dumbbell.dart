import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class SpinningDumbbell extends StatefulWidget {
  final double size;
  final double boxSize;

  const SpinningDumbbell({
    super.key,
    required this.size,
    required this.boxSize,
  });

  @override
  State<SpinningDumbbell> createState() => _SpinningDumbbellState();
}

class _SpinningDumbbellState extends State<SpinningDumbbell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.loaderSpin,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.boxSize,
      height: widget.boxSize,
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.fitness_center,
          color: Colors.white,
          size: widget.size,
        ),
      ),
    );
  }
}
