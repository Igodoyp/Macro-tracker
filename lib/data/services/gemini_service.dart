import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

abstract class MealAnalysisService {
  Future<Map<String, dynamic>> analyzeMeal({
    String? prompt,
    Uint8List? imageBytes,
    String imageMimeType,
  });
}

class GeminiNutritionService implements MealAnalysisService {
  final GenerativeModel _model;

  GeminiNutritionService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
          systemInstruction: Content.system('''
            Eres un experto en nutrición. Analiza la comida provista en el texto o en la imagen.
            Estima las proteínas, carbohidratos, grasas y calorías totales.
            Debes responder ÚNICAMENTE con un objeto JSON válido con la siguiente estructura:
            {
              "description": "Nombre resumido de la comida",
              "protein": 0.0,
              "carbs": 0.0,
              "fats": 0.0,
              "calories": 0
            }
            Si no se especifica el peso, asume porciones estándar. Sé lo más preciso posible.
          '''),
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
      parts.add(DataPart('image/jpeg', normalizedBytes));
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

    try {
      final response = await _model.generateContent([Content.multi(parts)]);

      if (response.text == null) {
        throw Exception('No se recibió respuesta de Gemini.');
      }

      return _decodeJsonResponse(response.text!);
    } catch (error) {
      throw Exception('Gemini falló al analizar la imagen: $error');
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