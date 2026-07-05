import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

abstract class NutritionRepositoryBase {
  Future<void> insertMeal(Map<String, dynamic> mealData);

  Future<List<Map<String, dynamic>>> fetchTodayMeals();

  Future<List<Map<String, dynamic>>> fetchSavedMeals();

  Future<Map<String, dynamic>?> fetchActiveMacroGoals();

  Future<void> saveMeal(Map<String, dynamic> mealData);

  Future<void> saveMacroGoals({
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  });

  Future<void> removeSavedMeal(String savedMealId);

  Future<void> deleteMeal(String mealId);

  Future<void> logDailyWeight(double weight);
}

class NutritionRepository implements NutritionRepositoryBase {
  final _supabase = Supabase.instance.client;

  String get _currentUserId {
    final currentUserId = _supabase.auth.currentUser?.id ?? AppConfig.fallbackUserId;

    if (currentUserId.isEmpty) {
      throw StateError(
        'No hay usuario autenticado y falta SUPABASE_DEMO_USER_ID para registrar datos.',
      );
    }

    return currentUserId;
  }

  @override
  Future<void> insertMeal(Map<String, dynamic> mealData) async {
    await _supabase.from('meals').insert({
      'user_id': _currentUserId,
      'description': mealData['description'],
      'protein': mealData['protein'],
      'carbs': mealData['carbs'],
      'fats': mealData['fats'],
      'calories': mealData['calories'],
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTodayMeals() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final response = await _supabase
        .from('meals')
        .select()
        .eq('user_id', _currentUserId)
        .gte('created_at', '${today}T00:00:00')
        .lte('created_at', '${today}T23:59:59');

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSavedMeals() async {
    final response = await _supabase
        .from('saved_meals')
        .select()
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveMacroGoals() async {
    final response = await _supabase
        .from('macro_goals')
        .select()
        .eq('user_id', _currentUserId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);

    final goals = List<Map<String, dynamic>>.from(response);

    if (goals.isEmpty) {
      return null;
    }

    return goals.first;
  }

  @override
  Future<void> saveMeal(Map<String, dynamic> mealData) async {
    await _supabase.from('saved_meals').upsert({
      'user_id': _currentUserId,
      'source_meal_id': mealData['id'],
      'description': mealData['description'],
      'protein': mealData['protein'],
      'carbs': mealData['carbs'],
      'fats': mealData['fats'],
      'calories': mealData['calories'],
    }, onConflict: 'user_id, source_meal_id');
  }

  @override
  Future<void> saveMacroGoals({
    required int calories,
    required int protein,
    required int carbs,
    required int fats,
  }) async {
    final activeGoals = await fetchActiveMacroGoals();

    final payload = {
      'user_id': _currentUserId,
      'target_calories': calories,
      'target_protein': protein,
      'target_carbs': carbs,
      'target_fats': fats,
      'is_active': true,
    };

    if (activeGoals == null) {
      await _supabase.from('macro_goals').insert(payload);
      return;
    }

    await _supabase
        .from('macro_goals')
        .update(payload)
        .eq('id', activeGoals['id'])
        .eq('user_id', _currentUserId);
  }

  @override
  Future<void> removeSavedMeal(String savedMealId) async {
    await _supabase
        .from('saved_meals')
        .delete()
        .eq('id', savedMealId)
        .eq('user_id', _currentUserId);
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    await _supabase
        .from('meals')
        .delete()
        .eq('id', mealId)
        .eq('user_id', _currentUserId);
  }

  @override
  Future<void> logDailyWeight(double weight) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await _supabase.from('weight_logs').upsert({
      'user_id': _currentUserId,
      'log_date': today,
      'weight_kg': weight,
    }, onConflict: 'user_id, log_date');
  }
}