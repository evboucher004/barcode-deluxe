import 'package:flutter/material.dart';

import '../services/advanced_options_store.dart';
import '../services/recent_inputs_store.dart';
import '../widgets/advanced_options.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// How far above centre the content sits, as a fraction of the body height.
  /// Was 0.20; shifted back down by 0.10 to land here.
  static const _upwardShiftFraction = 0.10;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Anchors the recent-inputs list to the text field. Like the Advanced
  // Options panel it lives in the app Overlay, so showing it costs no layout
  // space and the buttons below never move.
  final _recentLink = LayerLink();
  final _recentPortal = OverlayPortalController();

  /// Most recently encoded strings, newest first.
  var _recent = RecentInputsStore.value;

  /// Mirrors the state of the Advanced Options panel so [_generate] can apply
  /// the toggles. Seeded from the persisted value loaded at startup.
  var _options = AdvancedOptionsStore.value;

  /// Whether the box has anything in it, so the clear button can come and go.
  bool _hasText = false;

  /// Bumped to force the options panel to re-seed itself from [_options].
  /// Only changes when the scan screen may have edited the shared settings, so
  /// toggling a checkbox here does not rebuild (and therefore close) the panel.
  int _optionsEpoch = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncClearButton);
    // The result screen can scan again and record entries without coming back
    // through this screen, so track the store itself rather than only what
    // passes through [_showResult].
    RecentInputsStore.listenable.addListener(_refreshRecent);
  }

  @override
  void dispose() {
    RecentInputsStore.listenable.removeListener(_refreshRecent);
    _controller.removeListener(_syncClearButton);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Re-reads the store into [_recent], closing the panel if the history it
  /// is showing has gone away.
  void _refreshRecent() {
    if (!mounted) return;
    setState(() => _recent = RecentInputsStore.value);
    if (_recent.isEmpty) _hideRecentPanel();
  }

  /// Rebuilds only when the box crosses between empty and non-empty, so
  /// typing does not rebuild the screen on every keystroke.
  void _syncClearButton() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  /// Opens or closes the recent-inputs panel. Driven only by the History
  /// button, which is disabled while there is nothing to show.
  void _toggleRecentPanel() {
    if (_recent.isEmpty) return;
    // The panel drops down over the buttons, so get the keyboard out of the
    // way rather than have the two fight for the same space.
    _focusNode.unfocus();
    _recentPortal.toggle();
  }

  void _hideRecentPanel() {
    if (_recentPortal.isShowing) _recentPortal.hide();
  }

  void _generate(String raw) {
    final encoded = _options.apply(raw);
    if (encoded.isEmpty) return;
    _showResult(encoded);
  }

  /// Funnel for both paths that start on this screen. Recording here is not
  /// the only way an entry is added — see the listener in [initState].
  void _showResult(String encoded) {
    // The panel lives in the app Overlay, which sits above every route, so
    // leaving it open would float it over the result screen.
    _hideRecentPanel();
    _focusNode.unfocus();

    // Updates the cache synchronously and notifies [_refreshRecent].
    RecentInputsStore.add(encoded);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(text: encoded)),
    );
  }

  /// Pastes a history entry into the field and closes the panel: it is a
  /// picker, and the choice has been made.
  void _useRecent(String entry) {
    _controller.value = TextEditingValue(
      text: entry,
      selection: TextSelection.collapsed(offset: entry.length),
    );
    _hideRecentPanel();
  }

  Widget _buildRecentPanel(double? width) {
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _recentLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            // Named so tests can tell panel entries apart from the History
            // button, which carries the same icon.
            key: const ValueKey('recent-inputs-panel'),
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _recent)
                  InkWell(
                    // Nothing in the panel should take focus; it is a picker
                    // that writes into the field it sits under.
                    canRequestFocus: false,
                    onTap: () => _useRecent(entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scanText() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (scanned == null || !mounted) return;

    // The scan screen shares the persisted Advanced Options and may have
    // changed them, so re-read before applying, otherwise the textbox and the
    // barcode could disagree.
    setState(() {
      _options = AdvancedOptionsStore.value;
      _optionsEpoch++;
    });

    final encoded = _options.apply(scanned);
    if (encoded.isEmpty) return;

    // Show exactly the characters the barcode encodes, cursor at the end.
    _controller.value = TextEditingValue(
      text: encoded,
      selection: TextSelection.collapsed(offset: encoded.length),
    );
    _showResult(encoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Deluxe')),
      // Tapping any empty part of the body dismisses the keyboard. Buttons and
      // the text field still receive their own taps: they sit deeper in the
      // tree and win the gesture arena.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          _hideRecentPanel();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Centring the content in the viewport and then reserving 2x the
            // shift as bottom padding lifts it by exactly
            // [_upwardShiftFraction] of the body height. Wrapping in a scroll
            // view means the expanded Advanced Options panel can never
            // overflow.
            //
            // minHeight is the *full* viewport height rather than a box 2x the
            // shift shorter. The Scaffold passes loose constraints and this
            // scroll view shrink-wraps its child, so a shorter box ended the
            // subtree above the bottom of the screen — and with it the hit
            // area of the tap-to-dismiss GestureDetector above, leaving a dead
            // strip along the bottom where tapping did not close the keyboard.
            final shift = constraints.maxHeight * _upwardShiftFraction;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + shift * 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, fieldConstraints) {
                          // Match the list to the field's width.
                          final width = fieldConstraints.maxWidth.isFinite
                              ? fieldConstraints.maxWidth
                              : null;
                          return CompositedTransformTarget(
                            link: _recentLink,
                            child: OverlayPortal(
                              controller: _recentPortal,
                              overlayChildBuilder: (_) =>
                                  _buildRecentPanel(width),
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Enter text to encode',
                                  border: const OutlineInputBorder(),
                                  // Only while there is something to clear.
                                  suffixIcon: _hasText
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          tooltip: 'Clear',
                                          onPressed: _controller.clear,
                                        )
                                      : null,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: _generate,
                              ),
                            ),
                          );
                        },
                      ),
                      // 16 original gap + 20 added spacer.
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.qr_code_2),
                              label: const Text('Generate barcode'),
                              onPressed: () => _generate(_controller.text),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icon-only, and outlined so the primary action
                          // beside it stays the emphasised one. Disabled
                          // until there is something to list.
                          OutlinedButton(
                            onPressed:
                                _recent.isEmpty ? null : _toggleRecentPanel,
                            child: const Icon(Icons.history),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan text with camera'),
                        onPressed: _scanText,
                      ),
                      const SizedBox(height: 8),
                      // Persists changes itself; this screen mirrors the value
                      // for _generate. The key re-seeds the panel when the scan
                      // screen has changed the shared settings.
                      AdvancedOptions(
                        key: ValueKey(_optionsEpoch),
                        initialValue: _options,
                        onChanged: (v) => setState(() => _options = v),
                        // Dismiss the keyboard, and the history panel, on open
                        // or close: neither should sit over the panel that
                        // drops down beneath.
                        onExpansionChanged: (_) {
                          FocusScope.of(context).unfocus();
                          _hideRecentPanel();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
