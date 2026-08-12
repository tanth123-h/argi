import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/domain/auth_input_validator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _consentGiven = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validatePassword(String password) {
    // Min 8 chars, at least 1 digit
    return password.length >= 8 && password.contains(RegExp(r'\d'));
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สร้างบัญชีใหม่',
                  style: Theme.of(ctx).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'กรอกข้อมูลเพื่อเริ่มใช้งานชาวนา AI',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'อีเมล',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: AuthInputValidator.emailError,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: 'อย่างน้อย 8 ตัวอักษร และมีตัวเลข 1 ตัว',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                    if (!_validatePassword(v)) {
                      return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษรและมีตัวเลขอย่างน้อย 1 ตัว';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'ยืนยันรหัสผ่าน',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) {
                      return 'รหัสผ่านไม่ตรงกัน';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // PDPA consent — must be unchecked by default (opt-in)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentGiven,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (v) =>
                          setState(() => _consentGiven = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _consentGiven = !_consentGiven),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(ctx).textTheme.bodyLarge,
                              children: const [
                                TextSpan(text: 'ฉันยอมรับ '),
                                TextSpan(
                                  text: 'นโยบายความเป็นส่วนตัว',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        ' และยินยอมให้แอปเก็บข้อมูลตาม PDPA'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _consentGiven
                      ? () {
                          if (_formKey.currentState!.validate()) {
                            // TODO: call auth provider signUp
                            ctx.go('/home');
                          }
                        }
                      : null,
                  child: const Text('สมัครสมาชิก'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => ctx.pop(),
                    child: const Text('มีบัญชีแล้ว? เข้าสู่ระบบ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
