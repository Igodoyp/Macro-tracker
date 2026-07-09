import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils.dart';
import '../../data/repositories/supabase_respository.dart';
import '../../data/services/gemini_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.mealAnalysisService,
  });

  final NutritionRepositoryBase repository;
  final MealAnalysisService mealAnalysisService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _todayMeals = [];
  List<Map<String, dynamic>> _savedMeals = [];
  Map<String, dynamic>? _macroGoals;
  int _calories = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        widget.repository.fetchTodayMeals(),
        widget.repository.fetchSavedMeals(),
        widget.repository.fetchActiveMacroGoals(),
      ]);

      _todayMeals = List<Map<String, dynamic>>.from(results[0] as List);
      _savedMeals = List<Map<String, dynamic>>.from(results[1] as List);
      _macroGoals = results[2] as Map<String, dynamic>?;
      _recalculateTotals();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _recalculateTotals() {
    _calories = _todayMeals.fold<int>(0, (sum, meal) => sum + asInt(meal['calories']));
    _protein = _todayMeals.fold<double>(0, (sum, meal) => sum + asDouble(meal['protein']));
    _carbs = _todayMeals.fold<double>(0, (sum, meal) => sum + asDouble(meal['carbs']));
    _fats = _todayMeals.fold<double>(0, (sum, meal) => sum + asDouble(meal['fats']));
  }

  Future<void> _saveMeal(Map<String, dynamic> meal) async {
    try {
      await widget.repository.saveMeal(meal);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardada en favoritos: ${meal['description'] ?? 'comida'}')),
      );
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la comida: $error')),
      );
    }
  }

  Future<void> _registerSavedMeal(Map<String, dynamic> meal) async {
    try {
      await widget.repository.insertMeal(meal);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registrada en hoy: ${meal['description'] ?? 'comida'}')),
      );
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la comida guardada: $error')),
      );
    }
  }

  Future<void> _deleteMeal(Map<String, dynamic> meal) async {
    final mealId = meal['id']?.toString();

    if (mealId == null || mealId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el ID de la comida para borrarla.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar comida'),
        content: Text('¿Quieres borrar "${meal['description'] ?? 'esta comida'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.deleteMeal(mealId);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comida eliminada: ${meal['description'] ?? 'comida'}')),
      );
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la comida: $error')),
      );
    }
  }

  Future<void> _showSavedMealsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Comidas guardadas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_savedMeals.isEmpty)
                const Text('Aún no has guardado comidas favoritas.')
              else
                SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.5,
                  child: ListView.separated(
                    itemCount: _savedMeals.length,
                    separatorBuilder: (context, index) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final meal = _savedMeals[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${meal['description'] ?? 'Comida'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${asInt(meal['calories'])} kcal · ${formatZeroOrOneDecimal(asDouble(meal['protein']))}P / ${formatZeroOrOneDecimal(asDouble(meal['carbs']))}C / ${formatZeroOrOneDecimal(asDouble(meal['fats']))}G',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Registrar en hoy',
                              onPressed: () async {
                                await _registerSavedMeal(meal);
                                if (!mounted) {
                                  return;
                                }

                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.playlist_add_rounded),
                            ),
                            IconButton(
                              tooltip: 'Quitar de guardadas',
                              onPressed: () async {
                                final savedMealId = meal['id']?.toString();

                                if (savedMealId == null || savedMealId.isEmpty) {
                                  return;
                                }

                                await widget.repository.removeSavedMeal(savedMealId);
                                if (!mounted) {
                                  return;
                                }

                                Navigator.pop(sheetContext);
                                await _loadDashboard();
                              },
                              icon: const Icon(Icons.bookmark_remove_outlined),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWeightDialog(BuildContext context) async {
    final weightController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registrar Peso de Hoy'),
          content: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso en kg',
              hintText: 'Ej. 75.5',
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text);

                if (weight == null) {
                  return;
                }

                try {
                  await widget.repository.logDailyWeight(weight);
                  if (!mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Peso registrado: ${formatOneDecimal(weight)} kg')),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo guardar el peso: $error')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      } finally { // <-- AGREGAR ESTO
      weightController.dispose();
    }
  }

  Future<void> _showMacroGoalsDialog() async {
    final existingGoals = _macroGoals;
    final caloriesController = TextEditingController(
      text: existingGoals == null ? '' : asInt(existingGoals['target_calories']).toString(),
    );
    final proteinController = TextEditingController(
      text: existingGoals == null ? '' : asInt(existingGoals['target_protein']).toString(),
    );
    final carbsController = TextEditingController(
      text: existingGoals == null ? '' : asInt(existingGoals['target_carbs']).toString(),
    );
    final fatsController = TextEditingController(
      text: existingGoals == null ? '' : asInt(existingGoals['target_fats']).toString(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> saveGoals() async {
                final calories = int.tryParse(caloriesController.text.trim());
                final protein = int.tryParse(proteinController.text.trim());
                final carbs = int.tryParse(carbsController.text.trim());
                final fats = int.tryParse(fatsController.text.trim());

                if (calories == null || protein == null || carbs == null || fats == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa los cuatro objetivos con números enteros.')),
                  );
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                try {
                  await widget.repository.saveMacroGoals(
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fats,
                  );

                  if (!mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                  await _loadDashboard();
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Objetivos de macros guardados.')),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudieron guardar los objetivos: $error')),
                  );
                } finally {
                  if (mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Objetivos de macros'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Calorías objetivo',
                          border: OutlineInputBorder(),
                          suffixText: 'kcal',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: proteinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Proteína objetivo',
                          border: OutlineInputBorder(),
                          suffixText: 'g',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: carbsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs objetivo',
                          border: OutlineInputBorder(),
                          suffixText: 'g',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fatsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grasas objetivo',
                          border: OutlineInputBorder(),
                          suffixText: 'g',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: isSaving ? null : saveGoals,
                    child: Text(isSaving ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      caloriesController.dispose();
      proteinController.dispose();
      carbsController.dispose();
      fatsController.dispose();
    }
  }

  Future<void> _showMealComposer() async {
    final promptController = TextEditingController();
    Uint8List? imageBytes;
    String? imageName;
    String imageMimeType = 'image/jpeg';
    

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> pickImage() async {
                final pickedImage = await _imagePicker.pickImage(source: ImageSource.gallery);

                if (pickedImage == null) {
                  return;
                }

                imageBytes = await pickedImage.readAsBytes();
                imageName = pickedImage.name;
                imageMimeType = _guessImageMimeType(pickedImage.name);

                setSheetState(() {});
              }

              Future<void> analyzeAndSaveMeal() async {
                final prompt = promptController.text.trim();

                if (prompt.isEmpty && imageBytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escribe algo o adjunta una foto.')),
                  );
                  return;
                }

                setSheetState(() {
                  _isSubmitting = true;
                });

                try {
                  // --- PASO 1: Agente de Percepción ---
                  final perceptionResult = await widget.mealAnalysisService.analyzeMeal(
                    prompt: prompt.isEmpty ? null : prompt,
                    imageBytes: imageBytes,
                    imageMimeType: imageMimeType,
                  );

                  final List<dynamic> alimentosDetectados = perceptionResult['alimentos'] ?? [];

                  if (alimentosDetectados.isEmpty) {
                    throw Exception('No se detectaron alimentos claros en la imagen o texto.');
                  }

                  // Extraer los nombres de los alimentos detectados
                  final List<String> nombresParaMacros = alimentosDetectados
                      .map((item) => item['name'] as String)
                      .toList();

                  // --- PASO 2: Agente de Nutrición ---
                  final geminiService = widget.mealAnalysisService as GeminiNutritionService;
                  final macrosPor100g = await geminiService.analyzeNutrition(nombresParaMacros);
                  final macrosReales = macrosPor100g['resultados'] ?? macrosPor100g;

                  print('=== NOMBRES BUSCADOS ===');
                  print(nombresParaMacros);
                  print('=== RESPUESTA DE GEMINI ===');
                  print(macrosReales);

                  // --- PASO 3: Fusión y Matemática ---
                  double totalProteinas = 0;
                  double totalCarbohidratos = 0;
                  double totalGrasas = 0;
                  double totalCalorias = 0;
                  List<String> descripciones = [];
                  
                  for (var alimento in alimentosDetectados) {
                    final nombre = alimento['name'];
                    final gramos = asDouble(alimento['grams']);
                    final factorMultiplicador = gramos / 100; 
                    
                    descripciones.add('$nombre (${gramos.toInt()}g)');

                    if (macrosReales.containsKey(nombre)) {
                      final macros = macrosReales[nombre];
                      // CORRECCIÓN 1: Usamos las llaves exactas que devuelve el agente de nutrición
                      totalProteinas += asDouble(macros['protein']) * factorMultiplicador;
                      totalCarbohidratos += asDouble(macros['carbs']) * factorMultiplicador;
                      totalGrasas += asDouble(macros['fats']) * factorMultiplicador;
                      totalCalorias += asDouble(macros['calories']) * factorMultiplicador;
                    }
                  }

                  // --- PASO 4: Construir el objeto para Supabase ---
                  final finalMealAnalysis = {
                    'description': descripciones.join(', '),
                    'protein': totalProteinas,
                    'carbs': totalCarbohidratos,
                    'fats': totalGrasas,
                    'calories': totalCalorias.toInt(),
                  };

                  // Guardar en base de datos
                  await widget.repository.insertMeal(finalMealAnalysis);

                  // CORRECCIÓN 2: Apagamos el estado de carga ANTES de destruir la ventana modal
                  setSheetState(() {
                    _isSubmitting = false;
                  });

                  if (!mounted) return;
                  Navigator.pop(sheetContext); // Aquí se destruye la ventana
                  await _loadDashboard();
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Comida guardada: ${finalMealAnalysis['description']}')),
                  );

                } catch (error) {
                  if (!mounted) return;
                  
                  // Si hay error, apagamos el estado de carga aquí sin destruir la ventana
                  setSheetState(() {
                    _isSubmitting = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo analizar la comida: $error')),
                  );
                }
                // ELIMINAMOS EL BLOQUE FINALLY POR COMPLETO
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 4,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Añadir comida con IA',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: promptController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Describe la comida',
                        hintText: 'Ej. 2 huevos revueltos con pan integral y café',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Adjuntar foto'),
                    ),
                    if (imageName != null) ...[
                      const SizedBox(height: 8),
                      Text('Archivo seleccionado: $imageName'),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : analyzeAndSaveMeal,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high_rounded),
                      label: Text(_isSubmitting ? 'Analizando...' : 'Analizar y guardar'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      } finally { // <-- AGREGAR ESTO
      promptController.dispose();
    }
  }

  Future<void> _showAddMealOptions() async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Qué vas a registrar?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.restaurant_rounded, size: 32),
              title: const Text('Plato de comida'),
              subtitle: const Text('Usa una foto o texto (Ej: 2 huevos y pan)'),
              onTap: () {
                Navigator.pop(context);
                _showMealComposer(); // El flujo de los agentes 1 y 2
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined, size: 32),
              title: const Text('Etiqueta Nutricional'),
              subtitle: const Text('Escanea el empaque de un producto'),
              onTap: () {
                Navigator.pop(context);
                _showLabelScanner(); // El flujo de los agentes 3 y 4
              },
            ),
          ],
        ),
      );
    },
  );
}

  String _guessImageMimeType(String fileName) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  Future<void> _showLabelScanner() async {
    // 1. Correctamente indentado hacia la derecha (dentro de la función)
    final contextController = TextEditingController();
    final gramsController = TextEditingController();
    Uint8List? imageBytes;
    String imageMimeType = 'image/jpeg';

    // 2. Envolvemos el modal en un try/finally para limpiar la memoria al salir
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              
              Future<void> pickLabelImage() async {
                final pickedImage = await _imagePicker.pickImage(source: ImageSource.gallery);
                if (pickedImage == null) return;
                imageBytes = await pickedImage.readAsBytes();
                imageMimeType = _guessImageMimeType(pickedImage.name);
                setSheetState(() {});
              }

              Future<void> analyzeAndSaveLabel() async {
                final labelContext = contextController.text.trim();
                final gramsConsumed = double.tryParse(gramsController.text.trim());

                if (imageBytes == null || labelContext.isEmpty || gramsConsumed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Falta la foto, el nombre o los gramos.')),
                  );
                  return;
                }

                setSheetState(() => _isSubmitting = true);

                try {
                  final geminiService = widget.mealAnalysisService as GeminiNutritionService;

                  final results = await Future.wait([
                    geminiService.analyzeNutritionLabel(imageBytes!, imageMimeType),
                    geminiService.labelContextAnalysis(labelContext),
                  ]);

                  final ocrData = results[0];
                  final contextData = results[1];

                  final multiplicador = gramsConsumed / 100;
                  final nombreFinal = '${contextData['brand'] ?? ''} ${contextData['category'] ?? ''} ${contextData['variant'] ?? ''}'.trim();

                  final finalMealAnalysis = {
                    'description': '$nombreFinal (${gramsConsumed.toInt()}g)',
                    'protein': asDouble(ocrData['protein_per_100g']) * multiplicador,
                    'carbs': asDouble(ocrData['carbs_per_100g']) * multiplicador,
                    'fats': asDouble(ocrData['fats_per_100g']) * multiplicador,
                    'calories': (asDouble(ocrData['calories_per_100g']) * multiplicador).toInt(),
                  };

                  await widget.repository.insertMeal(finalMealAnalysis);

                  setSheetState(() {
                    _isSubmitting = false;
                  });

                  if (!mounted) return;
                  Navigator.pop(sheetContext);
                  await _loadDashboard();
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Producto guardado: $nombreFinal')),
                  );

                } catch (error) {
                  if (!mounted) return;
                  
                  setSheetState(() {
                    _isSubmitting = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fallo en el escáner: $error')),
                  );
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 4,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Escanear Etiqueta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contextController,
                      decoration: const InputDecoration(
                        labelText: '¿Qué producto es?',
                        hintText: 'Ej: Yogurt Soprole Proteína Fresa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: gramsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '¿Cuántos gramos/ml consumiste?',
                        border: OutlineInputBorder(),
                        suffixText: 'g/ml',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : pickLabelImage,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(imageBytes == null ? 'Tomar foto a la etiqueta' : 'Cambiar foto'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : analyzeAndSaveLabel,
                      icon: _isSubmitting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(_isSubmitting ? 'Procesando...' : 'Escanear y Guardar'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      // 3. Cuando el modal se cierra (ya sea guardando o tocando afuera), limpiamos los controladores
      contextController.dispose();
      gramsController.dispose();
    }
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              '$_calories kcal',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            const Text('Consumidas', style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroColumn('Proteína', '${formatZeroOrOneDecimal(_protein)} g', Colors.redAccent),
                _buildMacroColumn('Carbs', '${formatZeroOrOneDecimal(_carbs)} g', Colors.orangeAccent),
                _buildMacroColumn('Grasas', '${formatZeroOrOneDecimal(_fats)} g', Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGoalRow({
    required String label,
    required double current,
    required int target,
    required Color color,
  }) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${formatZeroOrOneDecimal(current)} / $target'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: color.withOpacity(0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroGoalsCard(ThemeData theme) {
    final hasGoals = _macroGoals != null;
    final targetCalories = asInt(_macroGoals?['target_calories']);
    final targetProtein = asInt(_macroGoals?['target_protein']);
    final targetCarbs = asInt(_macroGoals?['target_carbs']);
    final targetFats = asInt(_macroGoals?['target_fats']);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Objetivos de macros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showMacroGoalsDialog,
                  tooltip: hasGoals ? 'Editar objetivos' : 'Fijar objetivos',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!hasGoals)
              const Text('Todavía no has definido un objetivo diario. Añádelo para ver tu progreso.')
            else ...[
              _buildMacroGoalRow(
                label: 'Calorías',
                current: _calories.toDouble(),
                target: targetCalories,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _buildMacroGoalRow(
                label: 'Proteína',
                current: _protein,
                target: targetProtein,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              _buildMacroGoalRow(
                label: 'Carbs',
                current: _carbs,
                target: targetCarbs,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              _buildMacroGoalRow(
                label: 'Grasas',
                current: _fats,
                target: targetFats,
                color: Colors.amber,
              ),
            ],
            if (!hasGoals) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showMacroGoalsDialog,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Fijar objetivos'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(Map<String, dynamic> meal) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${meal['description'] ?? 'Comida'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${asInt(meal['calories'])} kcal · ${formatZeroOrOneDecimal(asDouble(meal['protein']))}P / ${formatZeroOrOneDecimal(asDouble(meal['carbs']))}C / ${formatZeroOrOneDecimal(asDouble(meal['fats']))}G',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Guardar en favoritos',
            onPressed: () => _saveMeal(meal),
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar comida',
            onPressed: () => _deleteMeal(meal),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resumen Diario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddMealOptions, // Cambiado aquí
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir comida'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tus Macros de Hoy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No se pudo cargar el resumen',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadDashboard,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildMacroGoalsCard(theme),
                const SizedBox(height: 16),
                _buildSummaryCard(theme),
                const SizedBox(height: 32),
                const Text(
                  'Comidas de Hoy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _todayMeals.isEmpty
                        ? const Text('Todavía no hay comidas registradas hoy.')
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _todayMeals.length,
                            separatorBuilder: (context, index) => const Divider(height: 20),
                            itemBuilder: (context, index) => _buildMealItem(_todayMeals[index]),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Text(
                'Acciones Rápidas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context: context,
                icon: Icons.add_rounded, // Puedes cambiar el ícono a algo más general
                title: 'Añadir Comida',
                subtitle: 'Escanea códigos, usa fotos o texto',
                color: theme.colorScheme.primaryContainer,
                onTap: _showAddMealOptions, // <-- AHORA ABRE EL MENÚ NUEVO
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context: context,
                icon: Icons.bookmark_rounded,
                title: 'Comidas Guardadas',
                subtitle: 'Añade rápidamente tus favoritos',
                color: theme.colorScheme.secondaryContainer,
                onTap: _showSavedMealsSheet,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context: context,
                icon: Icons.flag_outlined,
                title: 'Objetivos de macros',
                subtitle: 'Define tus metas diarias de calorías y macros',
                color: theme.colorScheme.tertiaryContainer,
                onTap: _showMacroGoalsDialog,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context: context,
                icon: Icons.monitor_weight_rounded,
                title: 'Registrar Peso Diario',
                subtitle: 'Mantén el trackeo de tu progreso',
                color: theme.colorScheme.tertiaryContainer,
                onTap: () => _showWeightDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}