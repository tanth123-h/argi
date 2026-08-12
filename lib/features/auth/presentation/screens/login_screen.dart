import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/features/auth/domain/auth_input_validator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSignUpDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('ไม่พบบัญชีนี้'),
        content: const Text(
          'ยังไม่มีบัญชีสำหรับอีเมลนี้\nต้องการสมัครสมาชิกใหม่ด้วยข้อมูลที่กรอกไว้หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _signUp(ctx);
            },
            child: const Text('สมัครสมาชิก'),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp(BuildContext ctx) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signUpWithEmail(
            email: _identifierCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ! กรุณาตรวจสอบอีเมลเพื่อยืนยัน'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สมัครสมาชิกไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Logo / brand
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.grass,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verdant',
                style: Theme.of(ctx).textTheme.displayMedium?.copyWith(
                  color: AppTheme.primaryGreenDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI Smart Farming',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => ctx.push('/demo-preset'),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('เริ่มใช้งาน Demo'),
                ),
              ),
              const SizedBox(height: 32),

              // Login form
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: implement forgot password
                        },
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _isLoading = true);

                                try {
                                  final email = _identifierCtrl.text.trim();
                                  final password = _passwordCtrl.text;

                                  await ref
                                      .read(authProvider.notifier)
                                      .signInWithEmail(
                                        email: email,
                                        password: password,
                                      );

                                  if (context.mounted) {
                                    ctx.go('/home');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    final msg = e.toString();
                                    // If no account, offer to create one
                                    final noAccount =
                                        msg.contains('invalid_credentials') ||
                                        msg.contains(
                                          'Invalid login credentials',
                                        );
                                    if (noAccount) {
                                      _showSignUpDialog(ctx);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'เข้าสู่ระบบไม่สำเร็จ: $msg',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('เข้าสู่ระบบ'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ctx.push('/register'),
                      child: const Text('สมัครสมาชิก'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('หรือ'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }
}
