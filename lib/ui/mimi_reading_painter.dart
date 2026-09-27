import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'mimi_reading_pose.dart';

/// A small 2D character rig: facial deformation, a jointed foreleg, and a page
/// whose corner follows the gripping paw. Reuses the welcome art and MiMi's
/// existing closed-eye expression instead of changing the character's identity.
class ReadingKittenPainter extends CustomPainter {
  ReadingKittenPainter(this.artwork, this.progress, {this.blinkArtwork});

  final ui.Image artwork;
  final ui.Image? blinkArtwork;
  final double progress;
  static const _width = 381.0, _height = 327.0;
  static const _columns = 128, _rows = 110;
  static final _uv = _textureCoordinates();
  static final _indices = _triangles();
  static final _weights = _skinWeights();
  static final _edgeColors = Int32List.fromList([
    for (var i = 1; i < _uv.length; i += 2)
      ((_smooth(0, 3, _uv[i]) * 255).round() << 24) | 0xFFFFFF,
  ]);
  static final _shaders = Expando<ui.ImageShader>();
  ui.ImageShader get _shader => _shaders[artwork] ??= ui.ImageShader(
    artwork,
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
    filterQuality: FilterQuality.medium,
  );
  static final _pawOutline = Path()
    ..moveTo(222, 240)
    ..cubicTo(235, 236, 252, 244, 257, 252)
    ..cubicTo(265, 260, 263, 272, 252, 278)
    ..cubicTo(239, 284, 216, 278, 212, 268)
    ..cubicTo(207, 259, 212, 246, 222, 240)
    ..close();

  static Float32List _textureCoordinates() {
    final points = Float32List((_columns + 1) * (_rows + 1) * 2);
    for (var row = 0; row <= _rows; row++) {
      for (var col = 0; col <= _columns; col++) {
        final i = (row * (_columns + 1) + col) * 2;
        points[i] = _width * col / _columns;
        points[i + 1] = _height * row / _rows;
      }
    }
    return points;
  }

  static Uint16List _triangles() {
    final result = Uint16List(_columns * _rows * 6);
    var index = 0;
    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _columns; col++) {
        final a = row * (_columns + 1) + col, b = a + _columns + 1;
        for (final vertex in [a, b, a + 1, a + 1, b, b + 1]) {
          result[index++] = vertex;
        }
      }
    }
    return result;
  }

  static double _smooth(double a, double b, double value) {
    final t = ((value - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static Float32List _skinWeights() {
    final weights = Float32List(_uv.length * 2);
    for (var i = 0; i < _uv.length; i += 2) {
      final x = _uv[i], y = _uv[i + 1];
      var gaze = 0.0;
      for (final eye in const [Offset(140, 125), Offset(218, 146)]) {
        final dx = (x - eye.dx) / 21, dy = (y - eye.dy) / 22;
        gaze += 1 - _smooth(.8, 1.3, math.sqrt(dx * dx + dy * dy));
      }
      weights[i * 2] = gaze;
      weights[i * 2 + 1] =
          (1 - _smooth(177, 224, y)) *
          _smooth(28, 76, x) *
          (1 - _smooth(350, 381, x));
      weights[i * 2 + 2] =
          _smooth(175, 217, y) *
          (1 - _smooth(283, 322, y)) *
          _smooth(45, 70, x) *
          (1 - _smooth(250, 278, x));
      weights[i * 2 + 3] =
          _smooth(269, 292, x) *
          _smooth(188, 227, y) *
          (1 - _smooth(296, 323, y)) *
          (1 - _smooth(342, 375, x));
    }
    return weights;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _width, size.height / _height);
    // The ear reaches the source image's top edge. Let that entire edge move
    // with the head; a matching backdrop fills the space it reveals. Pinning
    // the edge would stretch the ear tip while its base rotates away.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, _height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF0EBFD), Color(0xFFF0EBFD), Color(0xFFF1E9FE)],
          stops: [0, .65, 1],
        ).createShader(const Rect.fromLTWH(0, 0, _width, _height)),
    );
    final pose = ReadingPose.at(progress);
    _drawBody(canvas, pose);
    if (blinkArtwork != null && pose.blink > 0) _drawBlink(canvas, pose);
    final reach = ((pose.paw - const Offset(234, 259)).distance / 10).clamp(
      0.0,
      1.0,
    );
    if (reach > 0) {
      _coverRestingFingers(canvas, reach);
      _drawArm(
        canvas,
        pose,
        (((pose.paw - const Offset(234, 259)).distance - 8) / 24).clamp(
          0.0,
          1.0,
        ),
      );
    }
    if (pose.pageVisible) _drawPage(canvas, pose);
    if (reach > 0) _drawPaw(canvas, pose);
    canvas.restore();
  }

  /// Positions shared by rendering and geometry regression checks.
  static Float32List bodyVertices(ReadingPose pose) {
    final points = Float32List(_uv.length);
    final sin = math.sin(pose.headAngle), cos = math.cos(pose.headAngle);
    for (var i = 0; i < _uv.length; i += 2) {
      final x = _uv[i], y = _uv[i + 1];
      var px = x, py = y;

      py += pose.gaze * _weights[i * 2];
      final head = _weights[i * 2 + 1];
      final hx = px - 177, hy = py - 211;
      px += (hx * cos - hy * sin - hx - .7 * pose.headDrop) * head;
      py += (hx * sin + hy * cos - hy + pose.headDrop) * head;

      // The supporting paw and book move together with the breathing chest.
      final chest = _weights[i * 2 + 2];
      px += pose.support.dx * chest;
      py += pose.support.dy * chest;
      final tail = _weights[i * 2 + 3];
      px += -(y - 304) * pose.tailAngle * tail;
      py += (x - 278) * pose.tailAngle * tail;
      points[i] = px;
      points[i + 1] = py;
    }
    return points;
  }

  void _drawBody(Canvas canvas, ReadingPose pose) {
    final mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      bodyVertices(pose),
      textureCoordinates: _uv,
      // Soften the cropped fur at the source boundary without pinning vertices.
      colors: _edgeColors,
      indices: _indices,
    );
    canvas.drawVertices(mesh, BlendMode.modulate, Paint()..shader = _shader);
    mesh.dispose();
  }

  void _drawBlink(Canvas canvas, ReadingPose pose) {
    canvas.save();
    canvas.translate(-.7 * pose.headDrop, pose.headDrop);
    canvas.translate(177, 211);
    canvas.rotate(pose.headAngle);
    canvas.translate(-177, -211);
    for (final (target, source) in const [
      (Offset(138, 125), Offset(155, 244)),
      (Offset(221, 146), Offset(300, 244)),
    ]) {
      canvas.save();
      canvas.translate(target.dx, target.dy + pose.gaze);
      canvas.rotate(.245);
      const bounds = Rect.fromLTWH(-37, -37, 74, 74);
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: pose.blink),
      );
      canvas.drawImageRect(
        blinkArtwork!,
        Rect.fromCenter(center: source, width: 132, height: 132),
        bounds,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
      canvas.drawOval(
        const Rect.fromLTWH(-34, -32, 68, 57),
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      canvas.restore();
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  void _coverRestingFingers(Canvas canvas, double opacity) {
    const bounds = Rect.fromLTWH(203, 233, 34, 52);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF8B559F),
            Color(0xFF784193),
            Color(0xFF552A6D),
            Color(0xFF3B1650),
            Color(0xFF643A7C),
          ],
          stops: [0, .24, .58, .88, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(205, 235, 45, 46)),
    );
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawPath(
      _pawOutline,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.7),
    );
    canvas.restore();
    canvas.restore();
  }

  void _drawArm(Canvas canvas, ReadingPose pose, double opacity) {
    const shoulder = Offset(237, 285);
    final wrist =
        pose.paw + ReadingPose.rotate(const Offset(12, 5), pose.pawAngle);
    final elbow = Offset(244, wrist.dy + (shoulder.dy - wrist.dy) * .45);
    const rows = 28, columns = 12;
    final positions = Float32List((rows + 1) * (columns + 1) * 2);
    final texture = Float32List(positions.length);
    final colors = Int32List(positions.length ~/ 2);
    final indices = Uint16List(rows * columns * 6);
    var index = 0;
    for (var row = 0; row <= rows; row++) {
      final t = row / rows;
      final center =
          shoulder * ((1 - t) * (1 - t)) +
          elbow * (2 * (1 - t) * t) +
          wrist * (t * t);
      final tangent =
          (elbow - shoulder) * (2 * (1 - t)) + (wrist - elbow) * (2 * t);
      final normal =
          Offset(-tangent.dy, tangent.dx) / math.max(1, tangent.distance);
      for (var col = 0; col <= columns; col++) {
        final across = col / columns * 2 - 1;
        final v = row * (columns + 1) + col;
        final point = center + normal * (across * (30 - t * 15));
        positions[v * 2] = point.dx;
        positions[v * 2 + 1] = point.dy;
        // Sample a clean patch of the original foreleg/chest fur. Feather the
        // outer mesh columns and shoulder into the original body.
        texture[v * 2] = 258 + across * 8;
        texture[v * 2 + 1] = 299 - t * 34;
        final alpha =
            opacity * (1 - _smooth(.7, 1, across.abs())) * _smooth(0, .08, t);
        colors[v] = ((alpha * 255).round() << 24) | 0xFFFFFF;
        if (row < rows && col < columns) {
          final next = v + columns + 1;
          for (final vertex in [v, next, v + 1, v + 1, next, next + 1]) {
            indices[index++] = vertex;
          }
        }
      }
    }
    final mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      colors: colors,
      indices: indices,
    );
    canvas.drawVertices(mesh, BlendMode.modulate, Paint()..shader = _shader);
    mesh.dispose();
  }

  void _drawPaw(Canvas canvas, ReadingPose pose) {
    canvas.save();
    canvas.translate(pose.paw.dx, pose.paw.dy);
    canvas.rotate(pose.pawAngle);
    canvas.translate(-234, -259);
    // Feather the fur at the cutout edge instead of a hard clipped silhouette.
    final bounds = _pawOutline.getBounds().inflate(3);
    canvas.saveLayer(bounds, Paint());
    canvas.drawImage(
      artwork,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawPath(
      _pawOutline,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.25),
    );
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  void _drawPage(Canvas canvas, ReadingPose pose) {
    final t = pose.page,
        spread = math.cos(t * math.pi),
        lift = math.sin(t * math.pi);
    final opacity = (math.min(t, 1 - t) / .05).clamp(0.0, 1.0);
    const front = Offset(129, 220), back = Offset(127, 211);
    final tip = pose.pageTip;
    final far = Offset(
      127 + (spread >= 0 ? 84 : 57) * spread,
      211 - (spread >= 0 ? 19 : 29) * spread.abs() - 56 * lift,
    );
    final frontMid =
        Offset.lerp(front, tip, .55)! + Offset(9 * lift, -8 * lift);
    final backMid = Offset.lerp(far, back, .5)! + Offset(8 * lift, -7 * lift);
    final page = Path()
      ..moveTo(front.dx, front.dy)
      ..quadraticBezierTo(frontMid.dx, frontMid.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + 4 * lift, far.dy + 7, far.dx, far.dy)
      ..quadraticBezierTo(backMid.dx, backMid.dy, back.dx, back.dy)
      ..close();
    canvas.drawPath(
      page.shift(Offset(2 * lift, 2 * lift)),
      Paint()
        ..color = const Color(0xFF70503B).withValues(alpha: .16 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      page,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFE9CA83).withValues(alpha: opacity),
            const Color(0xFFFFF7CF).withValues(alpha: opacity),
            const Color(0xFFFFFCE6).withValues(alpha: opacity),
          ],
          stops: const [0, .35, 1],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(page.getBounds()),
    );
    canvas.drawPath(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = const Color(0xFFDEC58E).withValues(alpha: .8 * opacity),
    );
  }

  @override
  bool shouldRepaint(ReadingKittenPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.artwork != artwork ||
      oldDelegate.blinkArtwork != blinkArtwork;
}
