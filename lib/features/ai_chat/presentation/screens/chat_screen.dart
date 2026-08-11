import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  _ChatMessage({required this.content, required this.isUser})
    : timestamp = DateTime.now();
}

// ── Screen ─────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _gemini = GeminiService();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Quick prompt chips
  static const _quickPrompts = [
    '🌾 แนะนำปุ๋ยให้หน่อย',
    '💧 ควรรดน้ำแค่ไหน',
    '📈 ราคาข้าวตอนนี้เป็นอย่างไร',
    '🐛 ป้องกันโรคพืชยังไง',
    '🌱 ระยะปลูกที่เหมาะสม',
    '💰 คำนวณต้นทุน-กำไร',
  ];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(
      _ChatMessage(
        content:
            'สวัสดีครับ! ผมคือชาวนา AI พร้อมช่วยเหลือคุณเรื่องการเกษตร 🌾\n\nถามได้เลยครับ เช่น การใส่ปุ๋ย การดูแลดิน โรคพืช หรือราคาตลาด',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildSoilContext() {
    final demoPreset = ref.read(demoModeNotifierProvider);
    if (demoPreset == DemoPreset.none) return '';
    final soil = DemoFixtures.soilFor(demoPreset);
    final farm = DemoFixtures.farmFor(demoPreset);
    return 'N=${soil.nitrogen.toStringAsFixed(0)}, P=${soil.phosphorus.toStringAsFixed(0)}, '
        'K=${soil.potassium.toStringAsFixed(0)} mg/kg, ความชื้น=${soil.moisture.toStringAsFixed(0)}%, '
        'pH=${soil.phLevel}';
  }

  String _buildFarmContext() {
    final demoPreset = ref.read(demoModeNotifierProvider);
    if (demoPreset == DemoPreset.none) return '';
    final farm = DemoFixtures.farmFor(demoPreset);
    return 'พืช: ${farm?.cropType ?? 'ข้าว'}, พื้นที่: ${farm?.areaRai ?? 5} ไร่';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(content: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m != _messages.last)
          .take(20)
          .map(
            (m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            },
          )
          .toList();

      final response = await _gemini.chat(
        message: text,
        history: history,
        soilContext: _buildSoilContext(),
        farmContext: _buildFarmContext(),
      );

      setState(() {
        _messages.add(_ChatMessage(content: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            content: 'ขออภัย เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ชาวนา AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Gemini 2.0',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add(
                _ChatMessage(
                  content: 'เริ่มต้นการสนทนาใหม่ครับ 🌾',
                  isUser: false,
                ),
              );
            }),
            tooltip: 'ล้างการสนทนา',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick prompt chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(
                  _quickPrompts[i],
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _sendMessage(_quickPrompts[i]),
                backgroundColor: AppTheme.primaryGreenLight,
                labelStyle: const TextStyle(color: AppTheme.primaryGreenDark),
                side: BorderSide.none,
              ),
            ),
          ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) return _TypingIndicator();
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // Input
          _InputBar(
            controller: _controller,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext ctx) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryGreen : AppTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing Indicator ────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delay: 0),
              SizedBox(width: 4),
              _Dot(delay: 200),
              SizedBox(width: 4),
              _Dot(delay: 400),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.primaryGreen,
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ── Input Bar ───────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'ถามเรื่องการเกษตร...',
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: isLoading ? null : onSend,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              onPressed: isLoading ? null : () => onSend(controller.text),
              backgroundColor: isLoading
                  ? AppTheme.textSecondary
                  : AppTheme.primaryGreen,
              elevation: 0,
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
