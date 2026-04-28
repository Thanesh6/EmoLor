import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Calls Claude (Anthropic) directly to summarise a single week of
/// analytics data into 2-3 parent-friendly sentences.
///
/// The API key is read from a build-time `--dart-define`:
///
///     flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
///
/// We deliberately do NOT bundle the key in the repo. For production
/// the recommended path is to proxy this request through a Supabase
/// Edge Function so the key never ships in the APK.
class AiInsightService {
  AiInsightService._();

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _apiKey =
      String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
  static const String _model = 'claude-haiku-4-5';
  static const String _anthropicVersion = '2023-06-01';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// Sends [prompt] to Claude and returns the assistant's plain-text reply.
  ///
  /// Throws an [Exception] with a short message on any failure — the
  /// dashboard catches it and shows "Could not generate summary."
  static Future<String> generateInsight(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'Claude API key not configured (pass --dart-define=ANTHROPIC_API_KEY=...).');
    }

    try {
      final response = await _dio.post(
        _endpoint,
        data: {
          'model': _model,
          'max_tokens': 350,
          'temperature': 0.2,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
        options: Options(
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': _anthropicVersion,
            'content-type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode != 200) {
        debugPrint('Claude API HTTP ${response.statusCode}: ${response.data}');
        throw Exception('AI service returned ${response.statusCode}.');
      }

      final body = response.data as Map<String, dynamic>;
      final content = body['content'] as List?;
      if (content == null || content.isEmpty) {
        throw Exception('AI response was empty.');
      }
      final firstBlock = content.first as Map<String, dynamic>;
      final text = firstBlock['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('AI response had no text.');
      }
      return text.trim();
    } on DioException catch (e) {
      debugPrint('Claude API DioException: ${e.message} — ${e.response?.data}');
      throw Exception('Network error contacting AI service.');
    }
  }
}
