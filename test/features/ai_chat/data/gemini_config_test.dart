import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/core/constants/app_constants.dart';

void main() {
  test('Gemini key is absent unless supplied at runtime', () {
    expect(AppConstants.geminiApiKey, isEmpty);
  });
}
