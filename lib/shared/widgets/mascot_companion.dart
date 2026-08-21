import 'package:flutter/material.dart';

enum MascotMood { neutral, happy, thinking, helpful, celebrating, confused, sleeping }

class MascotCompanion extends StatefulWidget {
  final MascotMood mood;
  final double size;
  final String? message;
  const MascotCompanion({super.key, this.mood = MascotMood.neutral, this.size = 96, this.message});
  @override State<MascotCompanion> createState() => _MascotCompanionState();
}

class _MascotCompanionState extends State<MascotCompanion> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override void dispose() { _controller.dispose(); super.dispose(); }
  String get asset => switch (widget.mood) {
    MascotMood.thinking => 'assets/images/mascot/mascot_loading.png',
    MascotMood.helpful => 'assets/images/mascot/mascot_weather.png',
    MascotMood.confused || MascotMood.sleeping => 'assets/images/mascot/mascot_rest.png',
    MascotMood.celebrating => 'assets/images/mascot/mascot_rice.png',
    MascotMood.happy || MascotMood.neutral => 'assets/images/mascot/mascot_main.png',
  };
  @override
  Widget build(BuildContext context) {
    final image = SizedBox(width: widget.size, height: widget.size, child: Image.asset(asset, fit: BoxFit.contain));
    final animated = MediaQuery.of(context).disableAnimations ? image : AnimatedBuilder(animation: _controller, builder: (_, child) => Transform.translate(offset: Offset(0, -2 * _controller.value), child: child), child: image);
    return Column(mainAxisSize: MainAxisSize.min, children: [animated, if (widget.message != null) ...[const SizedBox(height: 6), Text(widget.message!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF617064), fontWeight: FontWeight.w700))]]);
  }
}
