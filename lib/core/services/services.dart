import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/tools/tool_registry.dart';
import 'agents/agent_runner.dart';
import 'memory/memory_service.dart';
import 'providers/media_service.dart';
import 'providers/provider_store.dart';
import 'storage/database.dart';
import 'storage/vault.dart';

/// The dependency root. Built once at startup and handed down with `Provider`,
/// so nothing in the UI ever constructs a service itself.
class Services {
  Services._();

  late final Dio dio;
  late final DatabaseService database;
  late final SecureVault vault;
  late final ProviderStore providers;
  late final MemoryService memory;
  late final ToolRegistry tools;
  late final AgentRunner runner;
  late final ImageGenerationService images;
  late final VideoGenerationService videos;
  late final String workspacePath;

  Future<void> bootstrap() async {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    database = DatabaseService();
    await database.open();
    vault = SecureVault();
    providers = ProviderStore(database, vault, dio);
    await providers.load();
    memory = MemoryService(database);
    tools = ToolRegistry()..registerAll(defaultTools());
    runner = AgentRunner(dio: dio, tools: tools, memory: memory);
    images = ImageGenerationService(dio);
    videos = VideoGenerationService(dio);

    final docs = await getApplicationDocumentsDirectory();
    workspacePath = p.join(docs.path, 'workspace');
    await Directory(workspacePath).create(recursive: true);
  }

  static Future<Services> bootstrapAll() async {
    final services = Services._();
    await services.bootstrap();
    return services;
  }
}
