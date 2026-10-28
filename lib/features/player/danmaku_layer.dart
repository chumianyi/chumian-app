import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';

class DanmakuLayer extends StatelessWidget {
  const DanmakuLayer({super.key, required this.rows, required this.position, required this.opacity, required this.density});
  final List<Danmaku> rows;
  final double position, opacity, density;
  @override
  Widget build(BuildContext context) => IgnorePointer(child: ClipRect(child: LayoutBuilder(builder: (context, bounds) {
    final lanes = math.max(1, math.min(8, (bounds.maxHeight / 48 * density).floor()));
    final laneBottom = List<double>.filled(lanes, -999);
    final fixedTop = List<double>.filled(lanes, -999);
    final fixedBottom = List<double>.filled(lanes, -999);
    final widgets = <Widget>[];
    for (final d in rows) {
      final age = position - d.time;
      if (age < 0 || age > 9) continue;
      final fontSize = d.size.toDouble();
      final text = TextPainter(text: TextSpan(text: d.text, style: TextStyle(fontSize: fontSize)), textDirection: TextDirection.ltr, maxLines: 1)..layout();
      final width = text.width;
      text.dispose();
      double x, y;
      if (d.mode == 'scroll') {
        final speed = (bounds.maxWidth + width) / 8;
        int lane = laneBottom.indexWhere((t) => d.time >= t);
        if (lane < 0) continue;
        // A lane is reusable once the previous trailing edge has cleared the right boundary.
        laneBottom[lane] = d.time + (width + 32) / speed + .8;
        if (age > 8) continue;
        x = bounds.maxWidth - age * speed;
        y = 8 + lane * 44.0;
      } else {
        if (age > 4.5) continue;
        final occupied = d.mode == 'bottom' ? fixedBottom : fixedTop;
        final lane = occupied.indexWhere((t) => d.time >= t);
        if (lane < 0) continue;
        occupied[lane] = d.time + 4.5;
        x = (bounds.maxWidth - width) / 2;
        y = d.mode == 'bottom' ? bounds.maxHeight - 60 - lane * 44.0 : 8 + lane * 44.0;
      }
      widgets.add(Positioned(left: x, top: y, child: Opacity(opacity: opacity.clamp(.2, 1), child: Text(d.text, maxLines: 1,
        style: TextStyle(fontSize: fontSize, height: 1.1, color: Color(int.parse('FF${d.color.substring(1)}', radix: 16)),
          fontWeight: FontWeight.w600, shadows: const [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1,1))])))));
      if (widgets.length >= 60) break;
    }
    return Stack(children: widgets);
  })));
}
