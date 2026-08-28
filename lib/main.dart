import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/advanced_options_store.dart';
import 'services/recent_inputs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load saved state before the first frame, so the checkboxes render in their
  // persisted state rather than flashing the defaults, and the recent-inputs
  // list is ready the moment the text field is focused.
  await Future.wait([
    AdvancedOptionsStore.load(),
    RecentInputsStore.load(),
  ]);
  runApp(const BarcodeGenApp());
}

class BarcodeGenApp extends StatelessWidget {
  const BarcodeGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Deluxe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
