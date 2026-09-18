import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import '../core/services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pure black edge to edge — the system chrome dissolves into the app.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final services = await Services.bootstrapAll();
  runApp(IlqeyteApp(services: services));
}
