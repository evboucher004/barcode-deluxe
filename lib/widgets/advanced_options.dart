import 'package:flutter/material.dart';

import '../models/advanced_options_value.dart';
import '../services/advanced_options_store.dart';

// Re-exported so callers only need to import this file.
export '../models/advanced_options_value.dart';

/// Which way the [AdvancedOptions] panel opens from its button.
enum AdvancedOptionsDirection {
  /// Panel hangs below the button. Suits a button near the top of a screen.
  down,

  /// Panel rises above the button. Suits a button pinned to the bottom.
  up,
}

/// An "Advanced Options" button with a panel of toggles that opens next to it.
///
/// The panel is rendered in the app [Overlay] rather than inline, so opening
/// and closing it takes up no layout space: the button keeps its position and
/// nothing around it moves. The panel is anchored to the button with a
/// [LayerLink], so it tracks the button if the button itself moves.
///
/// Self-contained: it owns the open/closed state and the toggle values, and by
/// default it seeds itself from [AdvancedOptionsStore] and writes changes back
/// there. So it can be dropped onto any screen with no wiring and the user's
/// settings persist automatically:
///
/// ```dart
/// const AdvancedOptions()
/// ```
///
/// To react to changes, pass [onChanged]. To override the starting values,
/// pass [initialValue]. To opt out of persistence, set [persist] to false.
class AdvancedOptions extends StatefulWidget {
  /// Starting state of the toggles.
  ///
  /// Defaults to the persisted [AdvancedOptionsStore.value] when null.
  final AdvancedOptionsValue? initialValue;

  /// Called whenever a toggle changes, with the full updated value.
  final ValueChanged<AdvancedOptionsValue>? onChanged;

  /// Whether changes are written to [AdvancedOptionsStore].
  final bool persist;

  /// Whether the panel starts open.
  final bool initiallyExpanded;

  /// Called when the panel is opened or closed.
  final ValueChanged<bool>? onExpansionChanged;

  /// Gap between the button and the near edge of the panel.
  final double panelGap;

  /// Whether the panel opens downward or upward from the button.
  final AdvancedOptionsDirection direction;

  const AdvancedOptions({
    super.key,
    this.initialValue,
    this.onChanged,
    this.persist = true,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.panelGap = 8,
    this.direction = AdvancedOptionsDirection.down,
  });

  @override
  State<AdvancedOptions> createState() => _AdvancedOptionsState();
}

class _AdvancedOptionsState extends State<AdvancedOptions> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  late AdvancedOptionsValue _value =
      widget.initialValue ?? AdvancedOptionsStore.value;
  late bool _expanded = widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) {
      // The overlay cannot be populated until this widget is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _portal.show();
      });
    }
  }

  void _togglePanel() {
    setState(() => _expanded = !_expanded);
    _portal.toggle();
    widget.onExpansionChanged?.call(_expanded);
  }

  void _update(AdvancedOptionsValue next) {
    if (next == _value) return;
    setState(() => _value = next);
    if (widget.persist) {
      // Fire and forget: the store updates its cache synchronously and swallows
      // write failures, so the UI never blocks on disk.
      AdvancedOptionsStore.save(next);
    }
    widget.onChanged?.call(next);
  }

  bool get _opensUp => widget.direction == AdvancedOptionsDirection.up;

  Widget _buildPanel(double? width) {
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _link,
        // Hang the panel off whichever edge of the button it opens from: its
        // top-left below the button, or its bottom-left above it.
        targetAnchor:
            _opensUp ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor:
            _opensUp ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, _opensUp ? -widget.panelGap : widget.panelGap),
        child: Align(
          alignment:
              _opensUp ? Alignment.bottomLeft : Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: _value.removeSpaces,
                  title: const Text('Remove Spaces'),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  onChanged: (v) =>
                      _update(_value.copyWith(removeSpaces: v ?? false)),
                ),
                CheckboxListTile(
                  value: _value.alphanumericOnly,
                  title: const Text('Alphanumeric only'),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  onChanged: (v) =>
                      _update(_value.copyWith(alphanumericOnly: v ?? false)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Match the panel to the button's width when that width is known.
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (_) => _buildPanel(width),
            child: OutlinedButton(
              onPressed: _togglePanel,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tune),
                  const SizedBox(width: 8),
                  const Text('Advanced Options'),
                  const SizedBox(width: 4),
                  // Chevron points the way the panel will go, and flips to
                  // point back at the button once the panel is open.
                  AnimatedRotation(
                    turns: (_opensUp ? 0.5 : 0.0) + (_expanded ? 0.5 : 0.0),
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
