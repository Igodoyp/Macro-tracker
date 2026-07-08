import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import '../../core/system_prompts.dart';

abstract class MealAnalysisService {
  Future<Map<String, dynamic>> analyzeMeal({
    String? prompt,
    Uint8List? imageBytes,
    String imageMimeType,
  });
}

class GeminiNutritionService implements MealAnalysisService {
  final GenerativeModel _perceptionAgent;
  final GenerativeModel _nutritionAgent;
  final GenerativeModel _ocrAgent;
  final GenerativeModel labelContextAgent;
  GeminiNutritionService({required String apiKey})
        : _perceptionAgent = GenerativeModel(
              model: 'gemini-2.5-flash',
              apiKey: apiKey,
              generationConfig: GenerationConfig(
                responseMimeType: 'application/json',
              ),
              systemInstruction: Content.system(SystemPrompts.perceptionAgent),
            ),

          _nutritionAgent = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
            systemInstruction: Content.system(SystemPrompts.nutritionAgent),
          ),
          _ocrAgent = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
            systemInstruction: Content.system(SystemPrompts.ocrAgent),
          ),
          labelContextAgent = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
            systemInstruction: Content.system(SystemPrompts.labelContextAgent),
          );

  @override
  Future<Map<String, dynamic>> analyzeMeal({
    String? prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    final List<Part> parts = [];

    if (prompt != null && prompt.isNotEmpty) {
      parts.add(TextPart(prompt));
    }

    if (imageBytes != null) {
      final normalizedBytes = _normalizeImageBytes(imageBytes);
      parts.add(DataPart(imageMimeType, normalizedBytes));
    }

    if (parts.length == 1 && imageBytes != null && (prompt == null || prompt.isEmpty)) {
      parts.insert(
        0,
        TextPart(
          'Analiza la foto de la comida y estima proteínas, carbohidratos, grasas, calorías y un nombre resumido del plato.',
        ),
      );
    }

    if (parts.isEmpty) {
      throw Exception('Debes proveer al menos un texto o una imagen.');
    }


    //analizar cantidades y alimentos
    try {
      final response = await _perceptionAgent.generateContent([Content.multi(parts)]);

      if (response.text == null) {
        throw Exception('No se recibió respuesta de Gemini.');
      }

      return _decodeJsonResponse(response.text!);  //devuelve json de los alimentos y cantidades estimadas en gramos
    } catch (error) {
      throw Exception('Gemini falló al analizar la imagen: $error');
    }
  }


  //Preguntar por los macros en 100g de cada alimento
  Future<Map<String, dynamic>> analyzeNutrition(List<String> foodItems) async {

    final String listaFormateada = foodItems.join(', ');

    final prompt = 'Dame los macros por cada 100g de los siguientes alimentos: $listaFormateada';

    try {
      final response = await _nutritionAgent.generateContent([Content.text(prompt)]);
      return _decodeJsonResponse(response.text!);  //devuelve json de los macros por cada 100g de cada alimento
    } catch (error) {
      throw Exception('Gemini falló al analizar la nutrición: $error');
    }
  }

  //extrae alimentos y cantidades en base a un text
  Future<Map<String, dynamic>> labelContextAnalysis(String labelContext) async {
    try{
      final response = await labelContextAgent.generateContent([Content.text(labelContext)]);
      return _decodeJsonResponse(response.text!); 
    } catch (error) {
      throw Exception('Gemini falló al analizar el contexto de la etiqueta: $error');
    }
  }

  //analiza la imagen de nutrition label
  Future<Map<String, dynamic>> analyzeNutritionLabel(Uint8List imageBytes, String imageMimeType) async {

    final Uint8List normalizedBytes = _normalizeImageBytes(imageBytes);

    try{
      final response = await _ocrAgent.generateContent([Content.data(imageMimeType, normalizedBytes)]);
      return _decodeJsonResponse(response.text!); 
    } catch (error) {
      throw Exception('Gemini falló al analizar la etiqueta nutricional: $error');
    }

  }


  Uint8List _normalizeImageBytes(Uint8List imageBytes) {
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return imageBytes;
    }

    final targetWidth = decodedImage.width > 1280 ? 1280 : decodedImage.width;
    final resizedImage = targetWidth < decodedImage.width
        ? img.copyResize(decodedImage, width: targetWidth)
        : decodedImage;

    final encodedBytes = img.encodeJpg(resizedImage, quality: 85);
    return Uint8List.fromList(encodedBytes);
  }

  Map<String, dynamic> _decodeJsonResponse(String responseText) {
    final cleanedText = responseText.trim();
    final jsonText = cleanedText
        .replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^```\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$', caseSensitive: false), '');

    final decoded = jsonDecode(jsonText);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Gemini respondió un formato inesperado.');
    }

    return decoded;
  }
}