import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/domain/auth_input_validator.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signInWithEmail(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(error.toString()))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(String error) {
    if (error.contains('Email not confirmed')) return 'กรุณายืนยันอีเมลจากกล่องข้อความก่อนเข้าสู่ระบบ';
    if (error.contains('Invalid login credentials')) return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    return 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    height: 138,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.18)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x120B6B4A), blurRadius: 18, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset('assets/images/grow_a_garden_logo.png', width: 96, height: 96),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Grow a Garden', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.primaryGreenDark)),
                              const SizedBox(height: 4),
                              Text('ปลูกให้ดีขึ้นด้วยข้อมูลจริง', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('ยินดีต้อนรับ', style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('ผู้ช่วยดูแลแปลงของคุณด้วยข้อมูลที่เข้าใจง่าย', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'อีเมล', prefixIcon: Icon(Icons.email_outlined)), validator: AuthInputValidator.emailError),
                  const SizedBox(height: 14),
                  TextFormField(controller: _password, obscureText: _hidden, decoration: InputDecoration(labelText: 'รหัสผ่าน', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hidden = !_hidden))), validator: (value) => value == null || value.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('ลืมรหัสผ่าน?'))),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _loading ? null : _login, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: const Text('เข้าสู่ระบบ')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () => context.push('/register'), icon: const Icon(Icons.person_add_alt_1), label: const Text('สร้างบัญชีใหม่')),
                ]),
              ),
            ),
          ),
        ),
      );
}
