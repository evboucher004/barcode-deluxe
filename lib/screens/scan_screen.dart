import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../services/advanced_options_store.dart';
import '../widgets/advanced_options.dart';

/// Live camera view with a rectangular capture box.
/// On shutter press the photo is cropped to the box and OCR runs on the
/// crop only, so just the text inside the rectangle is used.
/// Pops with the recognized String, or null if cancelled.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Box center offset from screen center, as a fraction of height (- = up).
  static const _boxCenterYOffset = -0.20;

  // Gap between the zoom row and the Advanced Options button. Also used as
  // that button's panelGap, so the upward panel lands flush against the zoom
  // row.
  static const _optionsGapAbove = 5.0;

  // Gap below the button, between it and the bottom safe-area edge.
  static const _optionsGapBelow = 10.0;

  // Fixed zoom levels offered as buttons, top to bottom.
  static const _zoomPresets = [1.0, 2.0, 3.0];

  // The rail must be no taller than the 96px large FAB it sits beside, or it
  // would grow the controls column and push everything else up.
  // 3 * 30 + 2 * 2 = 94.
  static const _zoomPresetHeight = 30.0;
  static const _zoomPresetGap = 2.0;

  // Box size as fractions of the preview area; user-resizable via handles.
  double _wFrac = 0.68;
  double _hFrac = 0.0792;

  CameraController? _controller;
  // Kept alive for the life of the screen: constructing a TextRecognizer spins
  // up the native ML Kit model, so reusing it makes repeat captures faster.
  final _recognizer = TextRecognizer();
  bool _busy = false;
  String? _error;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;
  double _pinchBaseZoom = 1.0;

  /// Mirrors the shared Advanced Options, seeded from the persisted value.
  var _options = AdvancedOptionsStore.value;

  /// True while the options panel is open. The shutter is disabled during that
  /// time so a photo cannot be taken through the panel.
  bool _optionsOpen = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _minZoom = minZoom;
        // Cap the range; sensors often report huge digital maximums.
        _maxZoom = maxZoom.clamp(minZoom, 7.0);
        _zoom = 2.0.clamp(minZoom, _maxZoom);
      });
      await controller.setZoomLevel(_zoom);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  void _setZoom(double value) {
    final z = value.clamp(_minZoom, _maxZoom);
    if (z == _zoom) return;
    setState(() => _zoom = z);
    _controller?.setZoomLevel(z);
  }

  /// Maps the on-screen capture box to image pixel coordinates, assuming the
  /// preview fills the view with BoxFit.cover, then crops and OCRs it.
  Future<void> _capture(Size viewSize) async {
    final controller = _controller;
    // Never fire the shutter while the options panel is open.
    if (controller == null || _busy || _optionsOpen) return;
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();

      var image = img.decodeImage(await File(shot.path).readAsBytes());
      if (image == null) throw 'Could not decode photo';
      image = img.bakeOrientation(image); // apply EXIF rotation

      // BoxFit.cover mapping: view rect -> image rect.
      final scale = _max(
          viewSize.width / image.width, viewSize.height / image.height);
      final offX = (image.width * scale - viewSize.width) / 2;
      final offY = (image.height * scale - viewSize.height) / 2;

      // Capture box in view coordinates.
      final boxW = viewSize.width * _wFrac;
      final boxH = viewSize.height * _hFrac;
      final boxLeft = (viewSize.width - boxW) / 2;
      final boxTop = (viewSize.height - boxH) / 2 +
          viewSize.height * _boxCenterYOffset;

      // Convert to image coordinates and clamp.
      int x = ((boxLeft + offX) / scale).round().clamp(0, image.width - 1);
      int y = ((boxTop + offY) / scale).round().clamp(0, image.height - 1);
      int w = (boxW / scale).round().clamp(1, image.width - x);
      int h = (boxH / scale).round().clamp(1, image.height - y);

      final crop = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final dir = await getTemporaryDirectory();
      final cropFile = File('${dir.path}/ocr_crop.jpg')
        ..writeAsBytesSync(img.encodeJpg(crop, quality: 95));

      final result = await _recognizer
          .processImage(InputImage.fromFilePath(cropFile.path));

      final text = _options.apply(result.text.replaceAll('\n', ' '));
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in the box.')),
        );
      } else {
        Navigator.of(context).pop(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static double _max(double a, double b) => a > b ? a : b;

  // Symmetric resize about the box center. [deltaPx] is the change in the
  // full dimension in pixels.
  void _resizeWidth(double deltaPx, Size viewSize) {
    setState(() {
      _wFrac = ((viewSize.width * _wFrac + deltaPx) / viewSize.width)
          .clamp(0.2, 0.95);
    });
  }

  void _resizeHeight(double deltaPx, Size viewSize) {
    setState(() {
      _hFrac = ((viewSize.height * _hFrac + deltaPx) / viewSize.height)
          .clamp(0.04, 0.5);
    });
  }

  /// A fixed-zoom button. Disabled when the camera cannot reach [level], and
  /// filled in while that level is the current zoom.
  Widget _zoomPresetButton(double level) {
    final reachable = level >= _minZoom && level <= _maxZoom;
    // Tolerance, because the slider and the sensor produce fractional values.
    final selected = (_zoom - level).abs() < 0.05;
    return SizedBox(
      width: 46,
      height: _zoomPresetHeight,
      child: FilledButton(
        onPressed: reachable ? () => _setZoom(level) : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
          backgroundColor: selected ? Colors.white : Colors.black54,
          foregroundColor: selected ? Colors.black : Colors.white,
          disabledBackgroundColor: Colors.black26,
          disabledForegroundColor: Colors.white38,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          // Without this, Material pads the button out to a 48px tap target,
          // which would make the rail taller than the shutter.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text('${level.toStringAsFixed(0)}x'),
      ),
    );
  }

  /// A draggable dot centered at (x, y) with a 44px hit target.
  Widget _handle({
    required double x,
    required double y,
    required void Function(DragUpdateDetails) onDrag,
  }) {
    const hit = 44.0;
    return Positioned(
      left: x - hit / 2,
      top: y - hit / 2,
      width: hit,
      height: hit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onDrag,
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan text'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child:
                  Text(_error!, style: const TextStyle(color: Colors.white)))
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(builder: (context, constraints) {
                  final viewSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  final boxW = viewSize.width * _wFrac;
                  final boxH = viewSize.height * _hFrac;
                  final cx = viewSize.width / 2;
                  final cy = viewSize.height / 2 +
                      viewSize.height * _boxCenterYOffset;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Pinch-to-zoom applies ONLY to the preview + overlay;
                      // the bottom controls are outside this detector.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (_) => _pinchBaseZoom = _zoom,
                        onScaleUpdate: (d) {
                          if (d.pointerCount < 2) return; // pinch only
                          _setZoom(_pinchBaseZoom * d.scale);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Preview fills the area, cropped (cover) - must
                            // match the mapping math in _capture().
                            FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: controller.value.previewSize!.height,
                                height: controller.value.previewSize!.width,
                                child: CameraPreview(controller),
                              ),
                            ),
                            // Dimmed overlay with a clear capture box.
                            _BoxOverlay(
                              widthFraction: _wFrac,
                              heightFraction: _hFrac,
                              centerYOffset: _boxCenterYOffset,
                            ),
                          ],
                        ),
                      ),
                      const Align(
                        alignment: Alignment(0, -0.68),
                        child: Text(
                          'Line up the text inside the box',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Resize handles: a dot at each edge midpoint.
                      _handle(
                        x: cx - boxW / 2,
                        y: cy,
                        onDrag: (d) =>
                            _resizeWidth(-2 * d.delta.dx, viewSize),
                      ),
                      _handle(
                        x: cx + boxW / 2,
                        y: cy,
                        onDrag: (d) =>
                            _resizeWidth(2 * d.delta.dx, viewSize),
                      ),
                      _handle(
                        x: cx,
                        y: cy - boxH / 2,
                        onDrag: (d) =>
                            _resizeHeight(-2 * d.delta.dy, viewSize),
                      ),
                      _handle(
                        x: cx,
                        y: cy + boxH / 2,
                        onDrag: (d) =>
                            _resizeHeight(2 * d.delta.dy, viewSize),
                      ),
                      // Bottom controls: shutter, zoom bar, then the options
                      // button pinned last at the bottom of the screen.
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The zoom rail rides alongside the shutter and
                              // is deliberately shorter than it, so this row
                              // is exactly as tall as the shutter alone and
                              // nothing above or below shifts.
                              Row(
                                children: [
                                  // Equal flexible gutters keep the shutter
                                  // centred on screen, as it was before.
                                  const Expanded(child: SizedBox()),
                                  FloatingActionButton.large(
                                    // Disabled while the panel is open: the
                                    // panel covers the shutter, and this
                                    // guarantees a photo cannot be taken
                                    // through it.
                                    onPressed: (_busy || _optionsOpen)
                                        ? null
                                        : () => _capture(viewSize),
                                    child: _busy
                                        ? const CircularProgressIndicator()
                                        : const Icon(Icons.camera_alt),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        // Same 24px inset as the zoom row, so
                                        // the rail lines up directly above the
                                        // zoom readout at its right edge.
                                        padding:
                                            const EdgeInsets.only(right: 24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 1x at the top, 3x at the bottom.
                                            for (var i = 0;
                                                i < _zoomPresets.length;
                                                i++) ...[
                                              if (i > 0)
                                                const SizedBox(
                                                    height: _zoomPresetGap),
                                              _zoomPresetButton(
                                                  _zoomPresets[i]),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                // No bottom padding: the only gap between the
                                // zoom row and the options button below is
                                // _optionsGapAbove.
                                padding:
                                    const EdgeInsets.fromLTRB(24, 4, 24, 0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.zoom_out,
                                        color: Colors.white),
                                    Expanded(
                                      child: Slider(
                                        value: _zoom,
                                        min: _minZoom,
                                        max: _maxZoom,
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white38,
                                        onChanged: _setZoom,
                                      ),
                                    ),
                                    const Icon(Icons.zoom_in,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_zoom.toStringAsFixed(1)}x',
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: _optionsGapAbove),
                              // Dark theme so the button and its panel read
                              // correctly against the camera feed.
                              Theme(
                                data: ThemeData.dark(useMaterial3: true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AdvancedOptions(
                                      // Opens upward: the button is the last
                                      // thing on screen, so there is no room
                                      // beneath it.
                                      direction: AdvancedOptionsDirection.up,
                                      // Matches the spacer above, so the panel
                                      // sits flush against the zoom row and
                                      // covers the controls behind it.
                                      panelGap: _optionsGapAbove,
                                      onChanged: (v) =>
                                          setState(() => _options = v),
                                      onExpansionChanged: (open) =>
                                          setState(() => _optionsOpen = open),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: _optionsGapBelow),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
    );
  }
}

/// Dims everything except the capture rectangle with a rounded border.
class _BoxOverlay extends StatelessWidget {
  final double widthFraction;
  final double heightFraction;
  final double centerYOffset;
  const _BoxOverlay(
      {required this.widthFraction,
      required this.heightFraction,
      required this.centerYOffset});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          _BoxOverlayPainter(widthFraction, heightFraction, centerYOffset),
    );
  }
}

class _BoxOverlayPainter extends CustomPainter {
  final double wf, hf, yOff;
  _BoxOverlayPainter(this.wf, this.hf, this.yOff);

  @override
  void paint(Canvas canvas, Size size) {
    final boxW = size.width * wf;
    final boxH = size.height * hf;
    final rect = Rect.fromCenter(
        center: size.center(Offset(0, size.height * yOff)),
        width: boxW,
        height: boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black54);

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BoxOverlayPainter old) =>
      old.wf != wf || old.hf != hf || old.yOff != yOff;
}
