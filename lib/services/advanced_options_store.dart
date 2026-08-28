import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/advanced_options_value.dart';

/// Persists [AdvancedOptionsValue] to device storage so the toggles survive
/// between sessions.
///
/// Call [load] once during app startup; after that [value] is available
/// synchronously, so widgets can seed themselves without an async gap and
/// without briefly rendering the defaults.
class AdvancedOptionsStore {
  AdvancedOptionsStore._();

  static const _removeSpacesKey = 'advanced_options.remove_spaces';
  static const _alphanumericOnlyKey = 'advanced_options.alphanumeric_only';

  static AdvancedOptionsValue _value = const AdvancedOptionsValue();

  /// The most recently loaded or saved value.
  static AdvancedOptionsValue get value => _value;

  /// Reads the stored toggles into [value]. Falls back to defaults if nothing
  /// has been saved yet, or if storage is unavailable.
  static Future<AdvancedOptionsValue> load() async {
    // First-run fallbacks come from the class defaults, so there is only one
    // place to change a default.
    const defaults = AdvancedOptionsValue();
    try {
      final prefs = await SharedPreferences.getInstance();
      _value = AdvancedOptionsValue(
        removeSpaces: prefs.getBool(_removeSpacesKey) ?? defaults.removeSpaces,
        alphanumericOnly:
            prefs.getBool(_alphanumericOnlyKey) ?? defaults.alphanumericOnly,
      );
    } catch (e) {
      // Persistence is a convenience, never a reason to fail startup.
      debugPrint('AdvancedOptionsStore.load failed, using defaults: $e');
      _value = const AdvancedOptionsValue();
    }
    return _value;
  }

  /// Updates [value] immediately and writes it to storage in the background.
  static Future<void> save(AdvancedOptionsValue next) async {
    // Update the cache first so the UI never waits on disk.
    _value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_removeSpacesKey, next.removeSpaces);
      await prefs.setBool(_alphanumericOnlyKey, next.alphanumericOnly);
    } catch (e) {
      debugPrint('AdvancedOptionsStore.save failed: $e');
    }
  }

  /// Resets the in-memory cache. Intended for tests.
  @visibleForTesting
  static void resetCache() => _value = const AdvancedOptionsValue();
}
