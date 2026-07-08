// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/data/repositories/supabase_respository.dart';
import 'package:flutter_application_1/data/services/gemini_service.dart';

void main() {
  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        repository: _FakeRepository(),
        mealAnalysisService: _FakeMealAnalysisService(),
      ),
    );

    await tester.pump();

    expect(find.text('Resumen Diario'), findsOneWidget);
    expect(find.text('Tus Macros de Hoy'), findsOneWidget);
  });
}

class _FakeRepository implements NutritionRepositoryBase {
  @override
  Future<void> insertMeal(Map<String, dynamic> mealData) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchTodayMeals() async {
    return [
      {
        'description': 'Pollo con arroz',
        'protein': 35,
        'carbs': 42,
        'fats': 11,
        'calories': 420,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSavedMeals() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveMacroGoals() async {
    return null;
  }

  @override
  Future<void> saveMeal(Map<String, dynamic> mealData) async {}

  @override
  Future<void> saveMacroGoals({
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  }) async {}

  @override
  Future<void> removeSavedMeal(String savedMealId) async {}

  @override
  Future<void> deleteMeal(String mealId) async {}

  @override
  Future<void> logDailyWeight(double weight) async {}
}

class _FakeMealAnalysisService implements MealAnalysisService {
  @override
  Future<Map<String, dynamic>> analyzeMeal({
    String? prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    return {
      'description': 'Comida de prueba',
      'protein': 10,
      'carbs': 20,
      'fats': 5,
      'calories': 180,
    };
  }
}
