import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';

void main() {
  test('explains missing Gemini configuration', () {
    final message = GeminiService.readableError(
      StateError('Gemini API key is not configured'),
    );

    expect(message, contains('GEMINI_API_KEY'));
  });

  test('explains quota errors', () {
    expect(
      GeminiService.readableError(Exception('429 quota')),
      contains('โควตา'),
    );
  });
}
