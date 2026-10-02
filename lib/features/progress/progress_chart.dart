import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChartPoint {
  const ChartPoint(this.x, this.y, this.label);
  final double x, y;
  final String label;
}

class ProgressChart extends StatelessWidget {
  const ProgressChart({
    super.key,
    required this.points,
    required this.xLabel,
    required this.yLabel,
    this.connect = true,
    this.xTickLabel,
    this.emptyMessage = 'Ainda não há dados para este gráfico.',
  });
  final List<ChartPoint> points;
  final String xLabel, yLabel, emptyMessage;
  final String Function(double)? xTickLabel;
  final bool connect;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(yLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (points.isEmpty)
            SizedBox(height: 160, child: Center(child: Text(emptyMessage)))
          else
            Semantics(
              label:
                  'Gráfico de $yLabel por $xLabel. Valores detalhados abaixo.',
              image: true,
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ChartPainter(
                    points,
                    connect,
                    Theme.of(context).colorScheme,
                    xTickLabel,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text(xLabel)),
          if (points.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver valores do gráfico'),
              children: [
                for (final p in points)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.label),
                    subtitle: Text(
                      '$xLabel: ${xTickLabel?.call(p.x) ?? p.x.toStringAsFixed(1)} • $yLabel: ${p.y.toStringAsFixed(1)}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.connect, this.scheme, this.xTickLabel);
  final String Function(double)? xTickLabel;
  final List<ChartPoint> points;
  final bool connect;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final minX = points.map((p) => p.x).reduce(math.min),
        maxX = points.map((p) => p.x).reduce(math.max);
    final maxY = math.max(1.0, points.map((p) => p.y).reduce(math.max) * 1.15);
    final left = 48.0,
        top = 10.0,
        bottom = size.height - 30,
        right = size.width - 18;
    Offset offset(ChartPoint p) => Offset(
      left +
          (right - left) * (maxX == minX ? .5 : (p.x - minX) / (maxX - minX)),
      bottom - (bottom - top) * p.y / maxY,
    );
    void label(String value, Offset at) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at);
    }

    for (var i = 0; i <= 4; i++) {
      final y = bottom - (bottom - top) * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = scheme.outlineVariant
          ..strokeWidth = 1,
      );
      label((maxY * i / 4).toStringAsFixed(0), Offset(0, y - 7));
    }
    label(
      xTickLabel?.call(minX) ?? minX.toStringAsFixed(0),
      Offset(left, bottom + 8),
    );
    if (maxX != minX) {
      label(
        xTickLabel?.call(maxX) ?? maxX.toStringAsFixed(0),
        Offset(right - (xTickLabel == null ? 15 : 42), bottom + 8),
      );
    }
    if (connect && points.length > 1) {
      final path = Path()
        ..moveTo(offset(points.first).dx, offset(points.first).dy);
      for (final p in points.skip(1)) {
        final o = offset(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = scheme.primary
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var i = 0; i < points.length; i++) {
      final o = offset(points[i]);
      canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = connect
              ? scheme.primary
              : Color.lerp(
                  scheme.primary,
                  Colors.orange,
                  points.length < 2 ? 0 : i / (points.length - 1),
                )!,
      );
      canvas.drawCircle(o, 2, Paint()..color = scheme.surface);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.scheme != scheme ||
      old.connect != connect ||
      old.xTickLabel != xTickLabel;
}
