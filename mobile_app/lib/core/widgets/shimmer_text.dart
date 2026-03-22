import 'package:flutter/material.dart';

/// A text widget with 3 colors continuously traveling across
/// each letter from left to right.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final Duration duration;
  final TextAlign textAlign;

  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.colors = const [
      Color(0xFFFF6B6B), // coral red
      Color(0xFFFFD93D), // gold yellow
      Color(0xFF6BCB77), // green
    ],
    this.duration = const Duration(milliseconds: 2000),
    this.textAlign = TextAlign.center,
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _controller.value;
        final colors = widget.colors;
        final n = colors.length;

        // Build repeating color band that shifts with animation
        final gradientColors = <Color>[];
        final stops = <double>[];

        // Create enough repeats to cover the full width + offset
        for (int i = 0; i <= n * 2; i++) {
          final baseStop = i / n - offset;
          gradientColors.add(colors[i % n]);
          stops.add(baseStop);
        }

        // Filter to only stops in visible range [0..1] with padding
        final visibleColors = <Color>[];
        final visibleStops = <double>[];
        for (int i = 0; i < stops.length; i++) {
          if (stops[i] >= -0.5 && stops[i] <= 1.5) {
            visibleColors.add(gradientColors[i]);
            visibleStops.add(stops[i].clamp(0.0, 1.0));
          }
        }

        // Ensure we have at least 2 colors
        if (visibleColors.length < 2) {
          visibleColors.clear();
          visibleStops.clear();
          visibleColors.addAll([colors[0], colors[1 % n]]);
          visibleStops.addAll([0.0, 1.0]);
        }

        // Deduplicate identical consecutive stops
        final finalColors = <Color>[visibleColors.first];
        final finalStops = <double>[visibleStops.first];
        for (int i = 1; i < visibleStops.length; i++) {
          if (visibleStops[i] > finalStops.last + 0.001) {
            finalColors.add(visibleColors[i]);
            finalStops.add(visibleStops[i]);
          }
        }

        if (finalColors.length < 2) {
          finalColors.add(colors[(colors.indexOf(finalColors.last) + 1) % n]);
          finalStops.add(1.0);
        }

        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: finalColors,
              stops: finalStops,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          ),
        );
      },
    );
  }
}
