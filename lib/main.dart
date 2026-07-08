import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'data/repositories/supabase_respository.dart';
import 'data/services/gemini_service.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.hasSupabaseCredentials) {
    runApp(
      const _ConfigurationErrorApp(
        message:
            'Faltan SUPABASE_URL y SUPABASE_ANON_KEY.',
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    MyApp(
      repository: NutritionRepository(),
      mealAnalysisService: AppConfig.hasGeminiCredentials
          ? GeminiNutritionService(apiKey: AppConfig.geminiApiKey)
          : const _DisabledMealAnalysisService(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.mealAnalysisService,
  });

  final NutritionRepositoryBase repository;
  final MealAnalysisService mealAnalysisService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Macro Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: DashboardScreen(
        repository: repository,
        mealAnalysisService: mealAnalysisService,
      ),
    );
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _DisabledMealAnalysisService implements MealAnalysisService {
  const _DisabledMealAnalysisService();

  @override
  Future<Map<String, dynamic>> analyzeMeal({
    String? prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) {
    throw StateError(
      'Falta configurar GEMINI_API_KEY. La app está lista, pero el análisis con IA no puede ejecutarse todavía.',
    );
  }
}