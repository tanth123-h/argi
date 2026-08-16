import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/auth/domain/auth_input_validator.dart';

void main() {
  test('accepts trimmed email with valid format', () {
    expect(AuthInputValidator.emailError(' farmer@example.com '), isNull);
  });

  test('rejects phone number because current Supabase flow uses email signup', () {
    expect(AuthInputValidator.emailError('0812345678'), isNotNull);
  });

  test('rejects email without domain', () {
    expect(AuthInputValidator.emailError('farmer@'), isNotNull);
  });
}
