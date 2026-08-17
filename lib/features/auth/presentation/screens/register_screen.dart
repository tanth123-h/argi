import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/domain/auth_input_validator.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/shared/widgets/mascot_companion.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _consent = false;
  bool _hidden = true;
  bool _created = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_consent || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signUpWithEmail(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) setState(() => _created = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authMessage(error.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMessage(String error) {
    if (error.contains('already registered') || error.contains('already been registered')) {
      return 'อีเมลนี้มีบัญชีแล้ว กรุณาเข้าสู่ระบบ';
    }
    if (error.contains('password')) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษรและมีตัวเลข';
    return 'สมัครสมาชิกไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }

  @override
  Widget build(BuildContext context) {
    if (_created) return _VerificationMessage(email: _email.text.trim());
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('สร้างบัญชี')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              const Center(child: MascotCompanion(mood: MascotMood.happy, size: 112)),
              const SizedBox(height: 8),
              Text('เริ่มต้นดูแลแปลงของคุณ', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('บัญชีเดียวสำหรับแผนที่ แผนการปลูก และคำแนะนำจากข้อมูลจริง', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 28),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'อีเมล', prefixIcon: Icon(Icons.email_outlined)),
                validator: AuthInputValidator.emailError,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  helperText: 'อย่างน้อย 8 ตัวอักษร และมีตัวเลข 1 ตัว',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hidden = !_hidden)),
                ),
                validator: (value) => value != null && value.length >= 8 && value.contains(RegExp(r'\d')) ? null : 'รหัสผ่านยังไม่ตรงตามเงื่อนไข',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _hidden,
                decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่าน', prefixIcon: Icon(Icons.lock_reset_outlined)),
                validator: (value) => value == _password.text ? null : 'รหัสผ่านไม่ตรงกัน',
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _consent,
                onChanged: (value) => setState(() => _consent = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('ยอมรับนโยบายความเป็นส่วนตัวและการจัดเก็บข้อมูลแปลง'),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _register,
                icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
                label: const Text('สร้างบัญชี'),
              ),
              TextButton(onPressed: () => context.pop(), child: const Text('มีบัญชีแล้ว เข้าสู่ระบบ')),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationMessage extends StatelessWidget {
  final String email;
  const _VerificationMessage({required this.email});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const MascotCompanion(mood: MascotMood.happy, size: 112, message: 'เกือบเสร็จแล้ว'),
                const SizedBox(height: 24),
                Text('ตรวจสอบอีเมลของคุณ', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('เราได้ส่งลิงก์ยืนยันไปที่\n$email\nกดยืนยันก่อนกลับมาเข้าสู่ระบบ', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton(onPressed: () => context.go('/login'), child: const Text('กลับไปเข้าสู่ระบบ')),
              ]),
            ),
          ),
        ),
      );
}
