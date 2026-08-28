import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the most recent strings that were actually encoded as barcodes.
///
/// Call [load] once during app startup; after that [value] is available
/// synchronously so widgets can read it without an async gap.
///
/// Entries are recorded from more than one route (the home screen and the
/// result screen both encode), so the list is exposed as a [ValueListenable]
/// as well: a screen that displays the history listens to [listenable] and
/// stays correct no matter which route did the recording.
class RecentInputsStore {
  RecentInputsStore._();

  static const _key = 'recent_inputs';

  /// How many entries are kept. Older ones fall off the end.
  static const maxEntries = 5;

  static final ValueNotifier<List<String>> _notifier =
      ValueNotifier<List<String>>(const []);

  /// Most recent first.
  static List<String> get value => _notifier.value;

  /// Notifies whenever the history changes, from any route.
  static ValueListenable<List<String>> get listenable => _notifier;

  /// Reads the stored history. Falls back to empty if storage is unavailable.
  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key) ?? const <String>[];
      _notifier.value = List.unmodifiable(stored.take(maxEntries));
    } catch (e) {
      // History is a convenience, never a reason to fail startup.
      debugPrint('RecentInputsStore.load failed, starting empty: $e');
      _notifier.value = const [];
    }
    return value;
  }

  /// Records [entry] as the newest item.
  ///
  /// Re-encoding a string already in the list moves it to the front rather
  /// than duplicating it. [value] is updated synchronously; the write to disk
  /// happens in the background.
  static Future<void> add(String entry) async {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) return;

    final next = <String>[
      trimmed,
      // Drop any earlier occurrence so the list stays unique.
      ...value.where((e) => e != trimmed),
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    // Update the cache first so the UI never waits on disk. Assigning a new
    // list instance also notifies [listenable] synchronously.
    _notifier.value = List.unmodifiable(next);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, value);
    } catch (e) {
      debugPrint('RecentInputsStore.add failed: $e');
    }
  }

  /// Clears the in-memory cache. Intended for tests.
  @visibleForTesting
  static void resetCache() => _notifier.value = const [];
}
