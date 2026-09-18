import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/provider_store.dart';
import '../../core/services/services.dart';
import '../../features/chat/chat_controller.dart';
import '../../features/shell/shell_controller.dart';
import '../features/shell/app_shell.dart';
import 'theme/liquid_glass.dart';

class IlqeyteApp extends StatelessWidget {
  const IlqeyteApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider<ProviderStore>.value(value: services.providers),
        ChangeNotifierProvider<ChatController>(
          create: (_) => ChatController(services),
        ),
        ChangeNotifierProvider<ShellController>(
          create: (_) => ShellController(),
        ),
      ],
      child: MaterialApp(
        title: 'ilqeyte',
        debugShowCheckedModeBanner: false,
        theme: liquidGlassTheme(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
