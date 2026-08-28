import 'package:flutter/foundation.dart';

/// The set of advanced toggles the user can configure.
///
/// Immutable so it can be passed around and compared cheaply. Lives in its own
/// file so both the widget and the persistence layer can depend on it without
/// an import cycle.
@immutable
class AdvancedOptionsValue {
  final bool removeSpaces;
  final bool alphanumericOnly;

  /// Both toggles are on by default: the result is the safest input for the
  /// linear symbologies this app generates.
  const AdvancedOptionsValue({
    this.removeSpaces = true,
    this.alphanumericOnly = true,
  });

  AdvancedOptionsValue copyWith({
    bool? removeSpaces,
    bool? alphanumericOnly,
  }) {
    return AdvancedOptionsValue(
      removeSpaces: removeSpaces ?? this.removeSpaces,
      alphanumericOnly: alphanumericOnly ?? this.alphanumericOnly,
    );
  }

  /// Applies these options to [raw], returning the string that should
  /// actually be encoded.
  ///
  /// Lives here rather than on a screen so every caller gets identical
  /// behaviour.
  ///
  /// The two toggles are independent: [alphanumericOnly] deliberately spares
  /// whitespace so that [removeSpaces] stays the only control over spacing.
  String apply(String raw) {
    var text = raw;
    if (alphanumericOnly) {
      // Drops punctuation, symbols and non-ASCII letters (accented
      // characters, other scripts), which the linear symbologies this feeds
      // cannot encode. Whitespace is preserved here and handled below.
      text = text.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '');
    }
    if (removeSpaces) {
      // Every whitespace character, not just U+0020, so tabs and the newlines
      // that OCR output can carry are removed too.
      text = text.replaceAll(RegExp(r'\s+'), '');
    }
    // Trailing trim, because stripping punctuation can expose new edge
    // whitespace (e.g. "! hi !" -> " hi ").
    return text.trim();
  }

  @override
  bool operator ==(Object other) =>
      other is AdvancedOptionsValue &&
      other.removeSpaces == removeSpaces &&
      other.alphanumericOnly == alphanumericOnly;

  @override
  int get hashCode => Object.hash(removeSpaces, alphanumericOnly);

  @override
  String toString() => 'AdvancedOptionsValue(removeSpaces: $removeSpaces, '
      'alphanumericOnly: $alphanumericOnly)';
}
