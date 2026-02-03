import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/local/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize local storage service
  await LocalStorageService.instance.initialize();

  // Run the app with Riverpod
  runApp(
    const ProviderScope(
      child: FundAnalyzerApp(),
    ),
  );
}
