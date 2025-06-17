import 'dart:convert';
import 'package:dio/dio.dart';
import '../secrets.dart';

class GeminiService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://generativelanguage.googleapis.com/v1/',
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Stream<String> sendMessageStream(String prompt) async* {
    final url = 'models/gemini-2.0-flash:generateContent?key=$geminiApiKey';

    try {
      final response = await _dio.post(
        url,
        data: {
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        },
      );

      final candidates = response.data['candidates'];
      if (candidates != null && candidates.isNotEmpty) {
        final text = candidates[0]['content']['parts'][0]['text'];
        for (final word in text.split(' ')) {
          yield "$word ";
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } else {
        yield "[Réponse vide de Gemini]";
      }
    } catch (e) {
      print("Erreur Gemini HTTP : $e");
      yield "[Erreur lors de la requête Gemini]";
    }
  }
}
