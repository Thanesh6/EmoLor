import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logic/adaptive_engine.dart';
import '../features/child/presentation/help_button.dart';
import '../features/child/presentation/activity_exit_handler.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  Color _selectedColor = Colors.black;
  double _brushSize = 8.0;
  final List<DrawingPoint> _points = [];

  // Adaptive Engine for stroke frequency tracking
  final AdaptiveEngine _adaptiveEngine = AdaptiveEngine(
    overloadTapsPerSecond: 5.0,
  );

  // Fixed 8-color drawing palette — not linked to emotions.
  static const List<Color> _colors = [
    Color(0xFFE53935), // red
    Color(0xFFFF7043), // orange
    Color(0xFFFFD600), // yellow
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFEC407A), // pink
    Color(0xFF212121), // black
  ];

  @override
  void initState() {
    super.initState();
  }

  TextStyle _cuteTextStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  void _onStroke() {
    // Track strokes as "taps" for frequency detection
    _adaptiveEngine.recordTap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA8EDEA),
              Color(0xFFFED6E3),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Let\'s Draw!',
                          style: _cuteTextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B2541),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text('🎨', style: TextStyle(fontSize: 45)),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: Row(
                      children: [
                        // Drawing Canvas
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.purple.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                  border:
                                      Border.all(color: Colors.white, width: 5),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      _onStroke(); // Track stroke frequency
                                      setState(() {
                                        _points.add(DrawingPoint(
                                          offset: details.localPosition,
                                          color: _selectedColor,
                                          size: _brushSize,
                                        ));
                                      });
                                    },
                                    onPanEnd: (details) {
                                      _points.add(DrawingPoint.separator());
                                    },
                                    child: CustomPaint(
                                      painter: DrawingPainter(_points),
                                      size: Size.infinite,
                                    ),
                                  ),
                                ),
                              ),
                              // Eraser Button – bottom left of canvas
                              Positioned(
                                left: 30,
                                bottom: 30,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedColor = Colors.white),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _selectedColor == Colors.white
                                          ? const Color(0xFFD0D0D0)
                                          : const Color(0xFFEEEEEE),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _selectedColor == Colors.white
                                            ? const Color(0xFFBB6BD9)
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🧼',
                                            style: TextStyle(fontSize: 30)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Eraser',
                                          style: _cuteTextStyle(
                                            fontSize: 24,
                                            color: const Color(0xFF6B21A8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Clear Button – bottom right of canvas
                              Positioned(
                                right: 30,
                                bottom: 30,
                                child: GestureDetector(
                                  onTap: () => setState(() => _points.clear()),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE74C3C),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🗑️',
                                            style: TextStyle(fontSize: 30)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Clear',
                                          style: _cuteTextStyle(
                                            fontSize: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tools Panel
                        Container(
                          width: 176,
                          margin: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.95),
                                Colors.white.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎨', style: TextStyle(fontSize: 40)),
                              Text(
                                'Colors',
                                style: _cuteTextStyle(
                                    fontSize: 25,
                                    color: const Color(0xFF6B21A8)),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 11,
                                runSpacing: 11,
                                children: _colors.map((color) {
                                  final isSelected = _selectedColor == color;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedColor = color),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: isSelected ? 64 : 56,
                                      height: isSelected ? 64 : 56,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.black87
                                              : Colors.white,
                                          width: isSelected ? 3 : 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: isSelected ? 10 : 6,
                                          ),
                                        ],
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.black87, size: 28)
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 40),
                              const Text('✏️', style: TextStyle(fontSize: 36)),
                              Text(
                                'Size',
                                style: _cuteTextStyle(
                                    fontSize: 22,
                                    color: const Color(0xFF6B21A8)),
                              ),
                              Slider(
                                value: _brushSize,
                                min: 3,
                                max: 25,
                                activeColor: const Color(0xFFBB6BD9),
                                onChanged: (val) =>
                                    setState(() => _brushSize = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Back Button (UCD016: exit with save prompt)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: () => ActivityExitHandler.handleExitActivity(
                    context: context,
                    activityId: 'draw_free',
                    activityName: 'Draw',
                    activityEmoji: '🖌️',
                    buildProgressData: () => {
                      'strokeCount': _points.length,
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF6B21A8),
                      size: 34,
                    ),
                  ),
                ),
              ),
              // UCD015: Help button
              const Positioned(
                top: 20,
                right: 20,
                child: HelpButton(
                  activityId: 'draw_free',
                  activityEmoji: '🖌️',
                  activityName: 'Free Draw',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawingPoint {
  final Offset? offset;
  final Color color;
  final double size;
  final bool isSeparator;

  DrawingPoint({
    this.offset,
    this.color = Colors.black,
    this.size = 5.0,
    this.isSeparator = false,
  });

  factory DrawingPoint.separator() => DrawingPoint(isSeparator: true);
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (!points[i].isSeparator && !points[i + 1].isSeparator) {
        final paint = Paint()
          ..color = points[i].color
          ..strokeWidth = points[i].size
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (points[i].offset != null && points[i + 1].offset != null) {
          canvas.drawLine(points[i].offset!, points[i + 1].offset!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
