import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final name = user?.userMetadata?['full_name'] as String?;
    return Scaffold(
      backgroundColor: AppTheme.fieldCanvas,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              _TopBar(onLogout: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              }),
              const SizedBox(height: 26),
              _Greeting(name: name),
              const SizedBox(height: 20),
              _FieldHero(onCreate: () => context.push('/farms')),
              const SizedBox(height: 26),
              Text('วันนี้ในแปลงของคุณ', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              _EmptyStatus(onCreate: () => context.push('/farms')),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(child: Text('ทางลัด', style: Theme.of(context).textTheme.titleLarge)),
                Text('เริ่มได้ทันที', style: Theme.of(context).textTheme.labelMedium),
              ]),
              const SizedBox(height: 10),
              _QuickActions(
                onMap: () => context.push('/farms'),
                onSoil: () => context.push('/soil'),
                onAi: () => context.push('/ai'),
              ),
              const SizedBox(height: 24),
              const _TrustNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _TopBar({required this.onLogout});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppTheme.fieldInk, shape: BoxShape.circle), child: const Icon(Icons.grass, color: AppTheme.fieldSun, size: 23)),
        const SizedBox(width: 10),
        Text('ชาวนา AI', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.fieldInk, fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(tooltip: 'การแจ้งเตือน', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.fieldInk)),
        PopupMenuButton<String>(onSelected: (value) { if (value == 'logout') onLogout(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ'))]),
      ]);
}

class _Greeting extends StatelessWidget {
  final String? name;
  const _Greeting({this.name});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('สวัสดี${name == null ? '' : ' $name'}', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.fieldInk, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Row(children: [const Icon(Icons.location_on_outlined, size: 17, color: AppTheme.fieldClay), const SizedBox(width: 5), Text('ประเทศไทย  •  วันนี้', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.fieldMuted))]),
      ]);
}

class _FieldHero extends StatelessWidget {
  final VoidCallback onCreate;
  const _FieldHero({required this.onCreate});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: AppTheme.fieldInk,
          height: 236,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _FieldLinesPainter())),
            Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppTheme.fieldSun.withValues(alpha: .16), borderRadius: BorderRadius.circular(8)), child: const Text('เริ่มต้นใช้งาน', style: TextStyle(color: AppTheme.fieldSun, fontWeight: FontWeight.w700))),
              const Spacer(),
              Text('สร้างแผนที่แปลงแรก', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('วาดขอบเขตบนภาพดาวเทียม แล้วให้ชาวนา AI ช่วยดูแลต่อ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .76))),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: onCreate, style: FilledButton.styleFrom(backgroundColor: AppTheme.fieldSun, foregroundColor: AppTheme.fieldInk, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), icon: const Icon(Icons.add_location_alt_outlined, size: 19), label: const Text('เพิ่มแปลงแรก')),
            ])),
          ]),
        ),
      );
}

class _EmptyStatus extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyStatus({required this.onCreate});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppTheme.fieldPaper, border: Border.all(color: AppTheme.fieldLine), borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppTheme.fieldMist, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_outlined, color: AppTheme.fieldClay)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ยังไม่มีข้อมูลแปลง', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('เพิ่มแปลงเพื่อเริ่มติดตามดิน น้ำ และความเสี่ยง', style: Theme.of(context).textTheme.bodyMedium)])), IconButton(tooltip: 'เพิ่มแปลง', onPressed: onCreate, icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.fieldInk))]));
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onMap; final VoidCallback onSoil; final VoidCallback onAi;
  const _QuickActions({required this.onMap, required this.onSoil, required this.onAi});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _QuickAction(icon: Icons.map_outlined, title: 'แผนที่แปลง', color: AppTheme.fieldGreen, onTap: onMap)),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.science_outlined, title: 'ตรวจดิน', color: AppTheme.fieldClay, onTap: onSoil)),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.chat_bubble_outline_rounded, title: 'ถาม AI', color: AppTheme.fieldBlue, onTap: onAi)),
      ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String title; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), decoration: BoxDecoration(color: AppTheme.fieldPaper, border: Border.all(color: AppTheme.fieldLine), borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(icon, color: color, size: 27), const SizedBox(height: 9), Text(title, style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center)])));
}

class _TrustNote extends StatelessWidget {
  const _TrustNote();
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_outlined, size: 20, color: AppTheme.fieldGreen), const SizedBox(width: 8), Expanded(child: Text('คำแนะนำจะอ้างอิงจากข้อมูลแปลงและแหล่งวิจัยที่ตรวจสอบได้', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.fieldMuted)))]);
}

class _FieldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.fieldGreen.withValues(alpha: .55)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (var row = -2; row < 8; row++) {
      final path = Path()..moveTo(-30, size.height * .32 + row * 34);
      path.cubicTo(size.width * .25, size.height * .18 + row * 34, size.width * .56, size.height * .48 + row * 34, size.width + 30, size.height * .24 + row * 34);
      canvas.drawPath(path, paint);
    }
    final sun = Paint()..color = AppTheme.fieldSun.withValues(alpha: .13);
    canvas.drawCircle(Offset(size.width - 12, 34), 64, sun);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
