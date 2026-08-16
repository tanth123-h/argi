import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@riverpod
class Auth extends _$Auth {
  @override
  User? build() {
    SupabaseClient supabase;
    try {
      supabase = Supabase.instance.client;
    } on AssertionError {
      return null;
    }

    // Listen to auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      state = data.session?.user;
    });

    return supabase.auth.currentUser;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final supabase = Supabase.instance.client;

    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final supabase = Supabase.instance.client;

    await supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signOut() async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    final supabase = Supabase.instance.client;
    await supabase.auth.resetPasswordForEmail(email);
  }
}

// Helper provider to check if user is authenticated
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  final user = ref.watch(authProvider);
  return user != null;
}
