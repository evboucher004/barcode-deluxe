import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barcode_gen/main.dart';
import 'package:barcode_gen/screens/result_screen.dart';
import 'package:barcode_gen/services/advanced_options_store.dart';
import 'package:barcode_gen/services/recent_inputs_store.dart';
import 'package:barcode_gen/widgets/advanced_options.dart';

void main() {
  setUp(() {
    // AdvancedOptions persists through SharedPreferences; without an in-memory
    // backing store every toggle would throw MissingPluginException.
    SharedPreferences.setMockInitialValues({});
    AdvancedOptionsStore.resetCache();
    RecentInputsStore.resetCache();
  });

  /// The contents of the result screen's editable encoded-text box.
  ///
  /// Scoped to the result screen: the home screen underneath it has a text
  /// field of its own, often holding the raw input this was made from.
  String encodedText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(ResultScreen),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  group('HomeScreen', () {
    testWidgets('shows the text field and both action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      expect(find.text('Barcode Deluxe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Enter text to encode'),
          findsOneWidget);
      expect(find.text('Generate barcode'), findsOneWidget);
      expect(find.text('Scan text with camera'), findsOneWidget);
      expect(find.byType(AdvancedOptions), findsOneWidget);
    });

    testWidgets('empty input does not navigate to the result screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.text('Barcode Deluxe'), findsOneWidget);
    });

    testWidgets('whitespace-only input does not navigate',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
    });

    testWidgets('entering text and generating pushes the result screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), 'HELLO123');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(encodedText(tester), 'HELLO123');
    });

    testWidgets('input is trimmed before being encoded',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), '  HELLO123  ');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), 'HELLO123');
    });

    testWidgets('tapping empty space unfocuses the textbox',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      bool hasFocus() =>
          tester.widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus;

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(hasFocus(), isTrue);

      // Near the bottom of the body, well clear of the centred controls.
      await tester.tapAt(const Offset(400, 580));
      await tester.pumpAndSettle();
      expect(hasFocus(), isFalse);
    });

    testWidgets('the tap-to-dismiss area reaches the bottom of the body',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      // The Scaffold passes loose constraints and SingleChildScrollView
      // shrink-wraps its child, so the body subtree — and the hit area of the
      // GestureDetector wrapping it — used to stop where the content ended,
      // leaving a strip along the bottom where a tap did nothing.
      expect(
        tester.getRect(find.byType(SingleChildScrollView)).bottom,
        tester.getRect(find.byType(Scaffold)).bottom,
      );
    });

    testWidgets('pressing Advanced Options unfocuses the textbox',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      bool hasFocus() =>
          tester.widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus;

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(hasFocus(), isTrue);

      // Opening the panel dismisses the keyboard...
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      expect(hasFocus(), isFalse);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      // ...and so does closing it again.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(hasFocus(), isTrue);

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      expect(hasFocus(), isFalse);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('tapping a button still activates it while focused',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), 'HELLO123');
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // The unfocus handler must not swallow taps aimed at children.
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
    });

    testWidgets('Alphanumeric only is on by default, so punctuation is dropped',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), 'HELLO-123');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), 'HELLO123');
    });
  });

  group('RecentInputsStore', () {
    test('starts empty and records newest first', () async {
      SharedPreferences.setMockInitialValues({});
      expect(RecentInputsStore.value, isEmpty);

      await RecentInputsStore.add('one');
      await RecentInputsStore.add('two');

      expect(RecentInputsStore.value, ['two', 'one']);
    });

    test('keeps only the five most recent', () async {
      SharedPreferences.setMockInitialValues({});
      for (final s in ['a', 'b', 'c', 'd', 'e', 'f']) {
        await RecentInputsStore.add(s);
      }

      expect(RecentInputsStore.value, ['f', 'e', 'd', 'c', 'b']);
      expect(RecentInputsStore.value, hasLength(RecentInputsStore.maxEntries));
    });

    test('re-adding an existing entry moves it to the front', () async {
      SharedPreferences.setMockInitialValues({});
      for (final s in ['a', 'b', 'c']) {
        await RecentInputsStore.add(s);
      }
      await RecentInputsStore.add('a');

      // Moved, not duplicated.
      expect(RecentInputsStore.value, ['a', 'c', 'b']);
    });

    test('ignores blank entries and trims the rest', () async {
      SharedPreferences.setMockInitialValues({});
      await RecentInputsStore.add('   ');
      expect(RecentInputsStore.value, isEmpty);

      await RecentInputsStore.add('  padded  ');
      expect(RecentInputsStore.value, ['padded']);
    });

    test('add updates the cache before the write completes', () async {
      SharedPreferences.setMockInitialValues({});
      final pending = RecentInputsStore.add('quick');
      expect(RecentInputsStore.value, ['quick']);
      await pending;
    });

    test('survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      await RecentInputsStore.add('kept');

      RecentInputsStore.resetCache();
      expect(RecentInputsStore.value, isEmpty);

      expect(await RecentInputsStore.load(), ['kept']);
    });

    test('load truncates an over-long stored list', () async {
      SharedPreferences.setMockInitialValues({
        'recent_inputs': ['1', '2', '3', '4', '5', '6', '7'],
      });

      expect(await RecentInputsStore.load(), ['1', '2', '3', '4', '5']);
    });

    test('listenable fires when an entry is added', () async {
      SharedPreferences.setMockInitialValues({});
      final seen = <List<String>>[];
      void record() => seen.add(RecentInputsStore.value);
      RecentInputsStore.listenable.addListener(record);
      addTearDown(() => RecentInputsStore.listenable.removeListener(record));

      await RecentInputsStore.add('one');
      await RecentInputsStore.add('two');

      expect(seen, [
        ['one'],
        ['two', 'one'],
      ]);
    });

    test('listenable does not fire for a rejected blank entry', () async {
      SharedPreferences.setMockInitialValues({});
      var fired = 0;
      void count() => fired++;
      RecentInputsStore.listenable.addListener(count);
      addTearDown(() => RecentInputsStore.listenable.removeListener(count));

      await RecentInputsStore.add('   ');

      expect(fired, 0);
      expect(RecentInputsStore.value, isEmpty);
    });
  });

  group('Recent inputs on the home screen', () {
    /// Generates [text], then returns to the home screen.
    Future<void> generateAndReturn(
        WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
      // enterText focuses the field, which pops the recent list over the
      // Generate button once there is history. Unfocus first so the tap below
      // reaches the button.
      await tester.tapAt(const Offset(400, 580));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    /// Clears the field, which also focuses it.
    Future<void> focusEmptyField(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
    }

    testWidgets('nothing appears when there is no history',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await focusEmptyField(tester);

      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('focusing the field reveals previously encoded strings',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await generateAndReturn(tester, 'HELLO123');
      await generateAndReturn(tester, 'WORLD456');

      await focusEmptyField(tester);

      // Newest first.
      expect(find.byIcon(Icons.history), findsNWidgets(2));
      expect(find.text('WORLD456'), findsOneWidget);
      expect(find.text('HELLO123'), findsOneWidget);
    });

    testWidgets('the list hides again when the field loses focus',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await generateAndReturn(tester, 'HELLO123');

      await focusEmptyField(tester);
      expect(find.byIcon(Icons.history), findsOneWidget);

      // Tap empty space to unfocus.
      await tester.tapAt(const Offset(400, 580));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('tapping an entry pastes it into the textbox',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await generateAndReturn(tester, 'HELLO123');

      await focusEmptyField(tester);
      await tester.tap(find.text('HELLO123'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'HELLO123');
      // Pasting must not steal focus, so the list stays up.
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('at most five entries are shown',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      for (final s in ['AAA1', 'BBB2', 'CCC3', 'DDD4', 'EEE5', 'FFF6']) {
        await generateAndReturn(tester, s);
      }

      await focusEmptyField(tester);

      expect(find.byIcon(Icons.history), findsNWidgets(5));
      // Oldest has fallen off, newest is present.
      expect(find.text('AAA1'), findsNothing);
      expect(find.text('BBB2'), findsOneWidget);
      expect(find.text('FFF6'), findsOneWidget);
    });

    testWidgets('the encoded string is recorded, not the raw input',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      // Defaults strip punctuation and spaces.
      await generateAndReturn(tester, 'AB-12 cd');

      await focusEmptyField(tester);

      expect(find.text('AB12cd'), findsOneWidget);
      expect(find.text('AB-12 cd'), findsNothing);
    });

    testWidgets('an entry recorded from the result screen reaches the list',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await tester.enterText(find.byType(TextField), 'HELLO123');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 580));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      // Standing on the result screen, record an entry the way its
      // "Scan new text" button does. The camera cannot run under the test
      // binding, so drive the store directly rather than the scan screen.
      // Not awaited: add() updates the cache and notifies listeners
      // synchronously, and the disk write is deliberately fire-and-forget.
      RecentInputsStore.add('SCANNED9');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await focusEmptyField(tester);

      // Both are listed, newest first, even though the second one never
      // passed through the home screen.
      expect(find.byIcon(Icons.history), findsNWidgets(2));
      expect(find.text('SCANNED9'), findsOneWidget);
      expect(find.text('HELLO123'), findsOneWidget);
    });
  });

  group('AdvancedOptionsValue defaults', () {
    test('both toggles are on by default', () {
      const v = AdvancedOptionsValue();
      expect(v.removeSpaces, isTrue);
      expect(v.alphanumericOnly, isTrue);
    });
  });

  group('AdvancedOptionsValue.apply', () {
    // Every toggle off, so each rule can be exercised in isolation.
    const none = AdvancedOptionsValue(
      removeSpaces: false,
      alphanumericOnly: false,
    );

    test('trims but keeps inner spaces when both toggles are off', () {
      expect(none.apply('  hello world  '), 'hello world');
    });

    test('removes every space when removeSpaces is on', () {
      const v = AdvancedOptionsValue(
        removeSpaces: true,
        alphanumericOnly: false,
      );
      expect(v.apply('9638 5074'), '96385074');
    });

    test('removes tabs and newlines too', () {
      const v = AdvancedOptionsValue(
        removeSpaces: true,
        alphanumericOnly: false,
      );
      expect(v.apply('ab\tcd\nef'), 'abcdef');
    });

    test('whitespace-only input collapses to empty', () {
      const v = AdvancedOptionsValue(
        removeSpaces: true,
        alphanumericOnly: false,
      );
      expect(v.apply('   '), isEmpty);
    });

    test('alphanumericOnly drops punctuation and symbols', () {
      const v = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(v.apply('a-b!c_1.2'), 'abc12');
    });

    test('alphanumericOnly keeps spaces when removeSpaces is off', () {
      // The two toggles are independent: only Remove Spaces controls spacing.
      const v = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(v.apply('hello world 42'), 'hello world 42');
    });

    test('alphanumericOnly drops non-ASCII letters but keeps the space', () {
      const v = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(v.apply('héllo wörld'), 'hllo wrld');
    });

    test('whitespace exposed by stripping punctuation is trimmed', () {
      const v = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(v.apply('! hi !'), 'hi');
    });

    test('both toggles together', () {
      const v = AdvancedOptionsValue(
        removeSpaces: true,
        alphanumericOnly: true,
      );
      expect(v.apply('  AB-12 cd/34  '), 'AB12cd34');
    });

    test('input that is entirely symbols collapses to empty', () {
      const v = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(v.apply('!!! ???'), isEmpty);
    });

    test('apply is idempotent for every toggle combination', () {
      // The scan screen applies the options before popping, and the home
      // screen applies them again to whatever it receives. Re-applying must
      // never change the result, or the textbox and the barcode would
      // disagree.
      const inputs = [
        '  AB-12 cd/34  ',
        '9638 5074',
        'héllo wörld',
        'plain',
        '!!! ???',
      ];
      for (final removeSpaces in [true, false]) {
        for (final alphanumericOnly in [true, false]) {
          final v = AdvancedOptionsValue(
            removeSpaces: removeSpaces,
            alphanumericOnly: alphanumericOnly,
          );
          for (final input in inputs) {
            final once = v.apply(input);
            expect(v.apply(once), once, reason: 'input=$input options=$v');
          }
        }
      }
    });
  });

  group('Options applied end to end', () {
    /// Opens the panel, drives each checkbox to the requested state, then
    /// closes the panel again so it does not sit over the Generate button.
    Future<void> setOptions(
      WidgetTester tester, {
      required bool removeSpaces,
      required bool alphanumericOnly,
    }) async {
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      Future<void> ensure(String label, bool wanted) async {
        final tile = tester.widget<CheckboxListTile>(find.ancestor(
          of: find.text(label),
          matching: find.byType(CheckboxListTile),
        ));
        if (tile.value != wanted) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }

      await ensure('Remove Spaces', removeSpaces);
      await ensure('Alphanumeric only', alphanumericOnly);

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
    }

    testWidgets('spaces survive when both toggles are off',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: false, alphanumericOnly: false);

      await tester.enterText(find.byType(TextField), '9638 5074');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), '9638 5074');
    });

    testWidgets('spaces are stripped when Remove Spaces is checked',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: true, alphanumericOnly: false);

      await tester.enterText(find.byType(TextField), '9638 5074');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      // Stripped to 8 digits with a valid EAN-8 checksum, so stripping also
      // changes which symbology is detected.
      expect(encodedText(tester), '96385074');
      expect(find.text('Auto-detected: EAN-8'), findsOneWidget);
    });

    testWidgets('Alphanumeric only alone does not remove spaces',
        (WidgetTester tester) async {
      // Regression: Alphanumeric only used to strip whitespace as well, so
      // spaces disappeared even with Remove Spaces unchecked.
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: false, alphanumericOnly: true);

      await tester.enterText(find.byType(TextField), '9638 5074');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), '9638 5074');
    });

    testWidgets('punctuation goes but spacing stays with only Alphanumeric on',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: false, alphanumericOnly: true);

      await tester.enterText(find.byType(TextField), 'AB-12 cd/34');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), 'AB12 cd34');
    });

    testWidgets('Alphanumeric only drops punctuation end to end',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: false, alphanumericOnly: true);

      await tester.enterText(find.byType(TextField), 'AB-12/cd');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(encodedText(tester), 'AB12cd');
    });

    testWidgets('whitespace-only input still does not navigate',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());
      await setOptions(tester, removeSpaces: true, alphanumericOnly: false);

      await tester.enterText(find.byType(TextField), '    ');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
    });

    testWidgets('input of only symbols does not navigate',
        (WidgetTester tester) async {
      await tester.pumpWidget(const BarcodeGenApp());

      await tester.enterText(find.byType(TextField), '!!! ???');
      await tester.tap(find.text('Generate barcode'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
    });
  });

  group('AdvancedOptionsStore', () {
    test('load returns defaults when nothing has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await AdvancedOptionsStore.load();

      expect(loaded, const AdvancedOptionsValue());
      expect(AdvancedOptionsStore.value, const AdvancedOptionsValue());
    });

    test('save then load round-trips both flags', () async {
      SharedPreferences.setMockInitialValues({});
      // Deliberately the opposite of the defaults, so a load that silently
      // fell back to defaults would fail this test.
      const saved = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: false,
      );
      await AdvancedOptionsStore.save(saved);

      AdvancedOptionsStore.resetCache();
      expect(AdvancedOptionsStore.value, const AdvancedOptionsValue());

      final loaded = await AdvancedOptionsStore.load();
      expect(loaded, saved);
    });

    test('save updates the cached value before the write completes', () async {
      SharedPreferences.setMockInitialValues({});
      const next = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: false,
      );

      final pending = AdvancedOptionsStore.save(next);
      // The cache must be usable immediately so the UI never waits on disk.
      expect(AdvancedOptionsStore.value, next);
      await pending;
    });

    test('load reads values written by a previous session', () async {
      SharedPreferences.setMockInitialValues({
        'advanced_options.remove_spaces': true,
        'advanced_options.alphanumeric_only': false,
      });

      final loaded = await AdvancedOptionsStore.load();
      expect(
        loaded,
        const AdvancedOptionsValue(
          removeSpaces: true,
          alphanumericOnly: false,
        ),
      );
    });

    test('a stored false overrides the on-by-default alphanumericOnly',
        () async {
      SharedPreferences.setMockInitialValues({
        'advanced_options.alphanumeric_only': false,
      });

      final loaded = await AdvancedOptionsStore.load();
      expect(loaded.alphanumericOnly, isFalse);
    });
  });

  group('Settings persistence', () {
    testWidgets('checking a box writes it to storage',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AdvancedOptions()),
      ));

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove Spaces'));
      await tester.pumpAndSettle();

      const expected = AdvancedOptionsValue(
        removeSpaces: false,
        alphanumericOnly: true,
      );
      expect(AdvancedOptionsStore.value, expected);

      final loaded = await AdvancedOptionsStore.load();
      expect(loaded, expected);
    });

    testWidgets('unchecking the on-by-default box persists the false',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AdvancedOptions()),
      ));

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alphanumeric only'));
      await tester.pumpAndSettle();

      final loaded = await AdvancedOptionsStore.load();
      expect(loaded.alphanumericOnly, isFalse);
    });

    testWidgets('a fresh widget seeds itself from the stored value',
        (WidgetTester tester) async {
      // Both stored false, i.e. the opposite of the defaults, so a widget
      // that ignored the store would fail here.
      SharedPreferences.setMockInitialValues({
        'advanced_options.remove_spaces': false,
        'advanced_options.alphanumeric_only': false,
      });
      await AdvancedOptionsStore.load();

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AdvancedOptions(initiallyExpanded: true)),
      ));
      await tester.pumpAndSettle();

      CheckboxListTile tileAt(String label) =>
          tester.widget<CheckboxListTile>(find.ancestor(
            of: find.text(label),
            matching: find.byType(CheckboxListTile),
          ));

      expect(tileAt('Remove Spaces').value, isFalse);
      expect(tileAt('Alphanumeric only').value, isFalse);
    });

    testWidgets('persist: false leaves storage untouched',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AdvancedOptions(persist: false)),
      ));

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove Spaces'));
      await tester.pumpAndSettle();

      expect(AdvancedOptionsStore.value, const AdvancedOptionsValue());
    });
  });

  group('AdvancedOptions', () {
    Widget wrap({ValueChanged<AdvancedOptionsValue>? onChanged}) => MaterialApp(
          home: Scaffold(body: AdvancedOptions(onChanged: onChanged)),
        );

    testWidgets('panel is hidden until the button is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Advanced Options'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('pressing the button reveals both checkboxes',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Spaces'), findsOneWidget);
      expect(find.text('Alphanumeric only'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });

    testWidgets('pressing the button again hides the panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('checkboxes open in their default state and toggle '
        'independently', (WidgetTester tester) async {
      final changes = <AdvancedOptionsValue>[];
      await tester.pumpWidget(wrap(onChanged: changes.add));

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      CheckboxListTile tileAt(String label) => tester
          .widget<CheckboxListTile>(find.ancestor(
            of: find.text(label),
            matching: find.byType(CheckboxListTile),
          ));

      expect(tileAt('Remove Spaces').value, isTrue);
      expect(tileAt('Alphanumeric only').value, isTrue);

      await tester.tap(find.text('Remove Spaces'));
      await tester.pumpAndSettle();

      // Toggling one box leaves the other alone.
      expect(tileAt('Remove Spaces').value, isFalse);
      expect(tileAt('Alphanumeric only').value, isTrue);
      expect(
        changes.single,
        const AdvancedOptionsValue(
          removeSpaces: false,
          alphanumericOnly: true,
        ),
      );
    });

    testWidgets('direction: down puts the panel below the button',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: AdvancedOptions(initiallyExpanded: true)),
        ),
      ));
      await tester.pumpAndSettle();

      final button = tester.getRect(find.byType(OutlinedButton));
      final panel = tester.getRect(find.byType(CheckboxListTile).first);
      expect(panel.top, greaterThanOrEqualTo(button.bottom));
    });

    testWidgets('direction: up puts the panel above the button',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdvancedOptions(
              initiallyExpanded: true,
              direction: AdvancedOptionsDirection.up,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final button = tester.getRect(find.byType(OutlinedButton));
      final panel = tester.getRect(find.byType(CheckboxListTile).last);
      expect(panel.bottom, lessThanOrEqualTo(button.top));
    });

    testWidgets('initialValue seeds the toggles',
        (WidgetTester tester) async {
      // Opposite of the defaults, so this fails if initialValue is ignored.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AdvancedOptions(
            initialValue: AdvancedOptionsValue(
              removeSpaces: false,
              alphanumericOnly: false,
            ),
            initiallyExpanded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      CheckboxListTile tileAt(String label) =>
          tester.widget<CheckboxListTile>(find.ancestor(
            of: find.text(label),
            matching: find.byType(CheckboxListTile),
          ));

      expect(tileAt('Remove Spaces').value, isFalse);
      expect(tileAt('Alphanumeric only').value, isFalse);
    });
  });

  group('ResultScreen', () {
    Widget wrap(String text) =>
        MaterialApp(home: ResultScreen(text: text));

    /// Whether the Refresh button beside the encoded-text box is enabled.
    bool refreshEnabled(WidgetTester tester) =>
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.refresh),
            )
            .onPressed !=
        null;

    testWidgets('reports the auto-detected symbology',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('9780306406157'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-detected: EAN-13 (ISBN)'), findsOneWidget);
      expect(find.text('EAN-13 (ISBN) (detected)'), findsOneWidget);
    });

    testWidgets('the detected type is preselected in the dropdown',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO-123'));
      await tester.pumpAndSettle();

      // The closed dropdown displays the current selection.
      expect(find.text('Code 128 (detected)'), findsOneWidget);
    });

    testWidgets('manual override switches the rendered symbology',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO-123'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).barcode.name,
        Barcode.code128().name,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code 39').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).barcode.name,
        Barcode.code39().name,
      );
      // The auto-detection label is unchanged by a manual override.
      expect(find.text('Auto-detected: Code 128'), findsOneWidget);
    });

    testWidgets('an unencodable override renders the error builder',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO-123'));
      await tester.pumpAndSettle();

      // Letters cannot be encoded as EAN-13.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EAN-13').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cannot encode with EAN-13'),
        findsOneWidget,
      );
    });

    testWidgets('the refresh button is disabled until the text changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO123'));
      await tester.pumpAndSettle();
      expect(refreshEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'HELLO124');
      await tester.pumpAndSettle();
      expect(refreshEnabled(tester), isTrue);

      // Typing the original back matches the barcode on screen again.
      await tester.enterText(find.byType(TextField), 'HELLO123');
      await tester.pumpAndSettle();
      expect(refreshEnabled(tester), isFalse);
    });

    testWidgets('whitespace alone is not a change',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO123'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  HELLO123  ');
      await tester.pumpAndSettle();
      expect(refreshEnabled(tester), isFalse);

      // Nor is an emptied box something to generate.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(refreshEnabled(tester), isFalse);
    });

    testWidgets('refreshing re-encodes and re-detects the symbology',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO-123'));
      await tester.pumpAndSettle();
      expect(find.text('Auto-detected: Code 128'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9780306406157');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).data,
        '9780306406157',
      );
      expect(find.text('Auto-detected: EAN-13 (ISBN)'), findsOneWidget);
      // Nothing left to regenerate.
      expect(refreshEnabled(tester), isFalse);
    });

    testWidgets('refreshing drops a manual override',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO-123'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code 39').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).barcode.name,
        Barcode.code39().name,
      );

      await tester.enterText(find.byType(TextField), 'OTHER-456');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // The override belonged to the previous content.
      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).barcode.name,
        Barcode.code128().name,
      );
    });

    testWidgets('the box is normalised to exactly what was encoded',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO123'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  WORLD456  ');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(encodedText(tester), 'WORLD456');
      expect(refreshEnabled(tester), isFalse);
    });

    testWidgets('a refreshed barcode is recorded in the history',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap('HELLO123'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'WORLD456');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(RecentInputsStore.value, ['WORLD456']);
    });
  });
}
