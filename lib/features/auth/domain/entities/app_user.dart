import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final bool isDemo;

  const AppUser({
    required this.id,
    this.email,
    this.phone,
    required this.createdAt,
    this.isDemo = false,
  });

  @override
  List<Object?> get props => [id, email, phone, isDemo];
}
