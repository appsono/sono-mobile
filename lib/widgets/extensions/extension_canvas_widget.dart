import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sono_extensions/sono_extensions.dart';

/// A full-canvas widget
///
/// On each display frame, [CustomPainter.paint] calls
/// [LuaRuntime.drawFrame], which sets the active [CanvasContext] and fires
/// sono_onDraw(width, height) in Lua. The extensions sono.canvas.*
/// calls execute synchronously on the real [Canvas] during that call
///
/// Wraps the canvas in a [GestureDetector] that forwards touch events to
/// sono_onTap(x, y) and sono_onDrag(dx, dy) hooks
class ExtensionCanvasWidget extends StatefulWidget {
  const ExtensionCanvasWidget({super.key, required this.runtime});

  final LuaRuntime runtime;

  @override
  State<ExtensionCanvasWidget> createState() => _ExtensionCanvasWidgetState();
}

class _ExtensionCanvasWidgetState extends State<ExtensionCanvasWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        if (!widget.runtime.isActive) return;
        try {
          widget.runtime.callHook('onTap', [
            d.localPosition.dx,
            d.localPosition.dy,
          ]);
        } catch (_) {}
      },
      onPanUpdate: (d) {
        if (!widget.runtime.isActive) return;
        try {
          widget.runtime.callHook('onDrag', [d.delta.dx, d.delta.dy]);
        } catch (_) {}
      },
      child: CustomPaint(
        painter: _ExtensionPainter(widget.runtime),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ExtensionPainter extends CustomPainter {
  _ExtensionPainter(this.runtime);

  final LuaRuntime runtime;

  @override
  void paint(Canvas canvas, Size size) {
    if (!runtime.isActive) return;
    try {
      runtime.drawFrame(canvas, size);
    } catch (_) {
      //silent: ignore Lua errors during draw to avoid crashing UI
    }
  }

  @override
  bool shouldRepaint(_ExtensionPainter old) => true;
}
