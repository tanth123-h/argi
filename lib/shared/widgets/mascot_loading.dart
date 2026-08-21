import 'package:flutter/material.dart';

class MascotLoading extends StatelessWidget {
  final String message;
  final double size;
  const MascotLoading({super.key, this.message = 'กำลังโหลดข้อมูลแปลง...', this.size = 92});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: size, height: size, child: Image.asset('assets/images/mascot/mascot_loading.png', fit: BoxFit.contain)),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(color: Color(0xFF617064), fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const SizedBox(width: 110, child: LinearProgressIndicator(minHeight: 4)),
    ]),
  );
}
