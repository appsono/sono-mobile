import 'package:flutter/material.dart';

extension ColorPrecisionHelper on Color {
  Color withIntValues({int? r, int? g, int? b, double? alpha}) {
    final double currentAlpha = alpha ?? a;

    return Color.fromRGBO(
      r ?? (this.r * 255).round(),
      g ?? (this.g * 255).round(),
      b ?? (this.b * 255).round(),
      currentAlpha.clamp(0.0, 1.0),
    );
  }
}