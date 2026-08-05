import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Rasterizes a colored circle with a centered Material icon glyph and a
/// white ring — matching the 2D map's marker widgets (see
/// _ResponderLocationMarker, _SosRequestMarker, etc. in responder_shell.dart)
/// — into raw RGBA bytes Mapbox's `addStyleImage` can register as a real
/// point-annotation icon. Plain `iconColor` on a PointAnnotation does
/// nothing without an actual registered image; this is what supplies one.
Future<({Uint8List rgba, int width, int height})> renderCircleIcon({
  required IconData icon,
  required Color backgroundColor,
  double diameter = 96,
  double borderWidth = 6,
}) async {
  final size = diameter.round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(diameter / 2, diameter / 2);

  canvas.drawCircle(center, diameter / 2, Paint()..color = backgroundColor);
  canvas.drawCircle(
    center,
    diameter / 2 - borderWidth / 2,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth,
  );

  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: diameter * 0.5,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
  )..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final image = await recorder.endRecording().toImage(size, size);
  // mapbox_maps_flutter's MbxImage.data is documented (and always was, on
  // every other Mapbox SDK) as raw pixel bytes - but the Android native
  // addStyleImage in 2.27.0 runs it through BitmapFactory.decodeByteArray,
  // which only understands encoded formats and returns null for raw RGBA,
  // NPEing right after. PNG-encoding here is a workaround for that
  // regression, not what the documented contract actually calls for -
  // revisit if a later mapbox_maps_flutter fixes decodeByteArray's input.
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return (rgba: byteData!.buffer.asUint8List(), width: size, height: size);
}
