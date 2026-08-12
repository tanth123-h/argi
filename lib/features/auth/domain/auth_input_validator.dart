class AuthInputValidator {
  AuthInputValidator._();

  static String? emailError(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'กรุณากรอกอีเมล';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'กรุณากรอกอีเมลให้ถูกต้อง เช่น farmer@example.com';
  }
}
