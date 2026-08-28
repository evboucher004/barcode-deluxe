import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';

import '../barcode_detector.dart';
import '../services/recent_inputs_store.dart';
import 'scan_screen.dart';

class ResultScreen extends StatefulWidget {
  final String text;
  const ResultScreen({super.key, required this.text});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _screenshot = ScreenshotController();

  /// The string the barcode on screen encodes. Diverges from
  /// [_textController] while the user edits the box, until Refresh is pressed.
  late String _text;

  /// Backs the editable "Encoded text" box.
  late final TextEditingController _textController;

  /// Whether the box holds something new that is worth re-encoding.
  bool _canRefresh = false;

  late String _selectedLabel;
  late DetectionResult _detected;

  @override
  void initState() {
    super.initState();
    _text = widget.text;
    _textController = TextEditingController(text: _text)
      ..addListener(_onTextChanged);
    _applyDetection();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  /// What Refresh would encode: the contents of the box, trimmed.
  String get _pendingText => _textController.text.trim();

  /// Rebuilds only when the button's enabled state actually flips, so typing
  /// does not re-render the barcode on every keystroke.
  void _onTextChanged() {
    final canRefresh = _pendingText.isNotEmpty && _pendingText != _text;
    if (canRefresh != _canRefresh) {
      setState(() => _canRefresh = canRefresh);
    }
  }

  /// Detects the symbology for [_text] and clears any manual override, which
  /// belonged to the previous content.
  void _applyDetection() {
    _detected = detectBarcode(_text);
    _selectedLabel = _detected.label;
  }

  /// Re-encodes using the contents of the box.
  ///
  /// The box is taken literally: it already holds the encoded string, so the
  /// Advanced Options are deliberately not re-applied to an edit made here.
  /// Guarded so it can never re-render the barcode it is already showing —
  /// [_canRefresh] disables the button for the same reason.
  void _refresh() {
    final next = _pendingText;
    if (next.isEmpty || next == _text) return;

    setState(() {
      _text = next;
      _applyDetection();
      _canRefresh = false;
    });

    // Normalise the box to exactly what is encoded; it may have carried
    // surrounding whitespace that [_pendingText] trimmed off.
    if (_textController.text != next) {
      _textController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }

    // It is a barcode now, so it belongs in the history like any other.
    RecentInputsStore.add(next);
  }

  /// The barcode currently selected (auto-detected or manual override).
  Barcode get _barcode =>
      _selectedLabel == _detected.label
          ? _detected.barcode
          : allSymbologies[_selectedLabel]!;

  Future<void> _scanNew() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (text != null && mounted) {
      // Same rule as the home screen: everything that actually becomes a
      // barcode is recorded, including scans started from here. The scan
      // screen has already applied the Advanced Options, so [text] is the
      // encoded string and tapping it in the history reproduces this barcode.
      RecentInputsStore.add(text);
      // Replace this result with a fresh one for the new text.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(text: text)),
      );
    }
  }

  Future<void> _save() async {
    final Uint8List? png = await _screenshot.capture(pixelRatio: 3);
    if (png == null) return;
    try {
      await Gal.putImageBytes(png,
          name: 'barcode_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to gallery')));
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: ${e.type.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown options: detected label first, then every other symbology.
    final options = <String>{
      _detected.label,
      ...allSymbologies.keys,
    }.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Your barcode')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Screenshot(
                  controller: _screenshot,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: BarcodeWidget(
                      barcode: _barcode,
                      data: _text,
                      height: 180,
                      errorBuilder: (context, error) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Cannot encode with $_selectedLabel:\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Encoded text',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    // Enter does the same thing as the button beside it.
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  // Disabled while the box matches the barcode on screen.
                  onPressed: _canRefresh ? _refresh : null,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate from this text',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Auto-detected: ${_detected.label}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLabel,
              decoration: const InputDecoration(
                labelText: 'Barcode type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final label in options)
                  DropdownMenuItem(
                    value: label,
                    child: Text(label == _detected.label
                        ? '$label (detected)'
                        : label),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedLabel = v!),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Save as Image'),
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan new text with barcode'),
              onPressed: _scanNew,
            ),
          ],
        ),
      ),
    );
  }
}
