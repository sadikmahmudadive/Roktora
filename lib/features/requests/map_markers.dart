import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws Roktora's map pins (blood-group bubbles for donors, a drop for requests) into
/// bitmaps, so the map matches the app instead of using stock markers.
class MarkerFactory {
  MarkerFactory._();

  static final _cache = <String, BitmapDescriptor>{};

  /// A round donor pin labeled with the blood group.
  static Future<BitmapDescriptor> donor({
    required String label,
    required Color color,
    required double pixelRatio,
    bool selected = false,
    bool dimmed = false,
  }) =>
      _get('d|$label|${color.toARGB32()}|$selected|$dimmed|$pixelRatio', 48, pixelRatio, (canvas, size) {
        final c = Offset(size / 2, size / 2);
        final r = size / 2 - 10; // leaves room for the selected halo
        _halo(canvas, c, r, color, selected);
        canvas.drawCircle(c, r, Paint()..color = (dimmed ? color.withValues(alpha: .6) : color));
        canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white);
        _text(canvas, label, c, 12, Colors.white);
      }, scale: selected ? 1.2 : 1);

  /// A request pin: a red disc with the brand drop and the group in a small badge.
  static Future<BitmapDescriptor> request({
    required String label,
    required Color color,
    required double pixelRatio,
    bool selected = false,
  }) =>
      _get('r|$label|${color.toARGB32()}|$selected|$pixelRatio', 52, pixelRatio, (canvas, size) {
        final c = Offset(size / 2, size / 2 - 1);
        final r = size / 2 - 8;
        _halo(canvas, c, r, color, selected);
        canvas.drawCircle(c, r, Paint()..color = color);
        canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white);
        _drop(canvas, c, r * 1.05);
        // Group badge, bottom-right.
        final bc = Offset(c.dx + r * .78, c.dy + r * .8);
        canvas.drawCircle(bc, 9.5, Paint()..color = Colors.white);
        canvas.drawCircle(bc, 9.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = color);
        _text(canvas, label.length > 3 ? '•' : label, bc, label.length > 2 ? 7.5 : 9, color);
      }, scale: selected ? 1.2 : 1);

  static void _halo(Canvas canvas, Offset c, double r, Color color, bool selected) {
    if (!selected) {
      canvas.drawCircle(c + const Offset(0, 2), r + 1, Paint()..color = Colors.black.withValues(alpha: .18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      return;
    }
    canvas.drawCircle(c, r + 7, Paint()..color = color.withValues(alpha: .25));
  }

  static void _text(Canvas canvas, String t, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700, fontFamily: 'InstrumentSans')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// The brand drop, fitted inside a box of [h] logical px centered on [c].
  static void _drop(Canvas canvas, Offset c, double h) {
    // Same outline as assets/brand/roktora-mark.svg (viewBox 520 440 702 1040).
    final p = Path()
      ..moveTo(875, 450)
      ..cubicTo(855, 560, 880, 650, 960, 760)
      ..cubicTo(1040, 870, 1212, 980, 1212, 1130)
      ..cubicTo(1212, 1320, 1060, 1470, 875, 1470)
      ..cubicTo(690, 1470, 530, 1320, 530, 1120)
      ..cubicTo(530, 1030, 560, 930, 597, 852)
      ..cubicTo(555, 960, 545, 1080, 625, 1180)
      ..cubicTo(655, 1218, 680, 1240, 710, 1240)
      ..cubicTo(745, 1240, 765, 1200, 745, 1170)
      ..cubicTo(735, 1150, 715, 1138, 700, 1125)
      ..cubicTo(640, 1070, 615, 990, 620, 900)
      ..cubicTo(630, 740, 760, 570, 875, 450)
      ..close();
    final b = p.getBounds();
    final s = (h * .72) / b.height;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-b.center.dx, -b.center.dy);
    canvas.drawPath(p, Paint()..color = Colors.white);
    canvas.restore();
  }

  static Future<BitmapDescriptor> _get(
    String key,
    double logicalSize,
    double pixelRatio,
    void Function(Canvas canvas, double size) paint, {
    double scale = 1,
  }) async {
    final hit = _cache[key];
    if (hit != null) return hit;
    final px = (logicalSize * scale * pixelRatio).ceil().toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(px / logicalSize); // paint in logical units, rasterize at device resolution
    paint(canvas, logicalSize);
    final img = await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final d = BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
      width: logicalSize * scale,
      height: logicalSize * scale,
    );
    return _cache[key] = d;
  }
}
