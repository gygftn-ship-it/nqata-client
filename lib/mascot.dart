import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

/// La mascotte Nqata : flotte doucement, cligne des yeux de temps en temps,
/// et parle dans une bulle avec un message qui dépend de ce qui se passe dans l'app.
class LivingMascot extends StatefulWidget {
  final double size;
  final String? message; // si fourni, remplace le message automatique
  final bool bubble; // afficher la bulle de parole
  const LivingMascot({super.key, this.size = 110, this.message, this.bubble = true});

  @override
  State<LivingMascot> createState() => _LivingMascotState();
}

class _LivingMascotState extends State<LivingMascot> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final rnd = Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    Future.delayed(Duration(milliseconds: 2200 + rnd.nextInt(3200)), () async {
      if (!mounted) return;
      await _blink.forward();
      if (!mounted) return;
      await _blink.reverse();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _blink.dispose();
    super.dispose();
  }

  String _autoMessage() {
    if (store.rewardsReady.isNotEmpty) return tr('Une récompense vous attend ! 🎉', 'مكافأة بانتظارك! 🎉');
    if (store.wallet.isEmpty) return tr('Scannez votre premier commerce pour commencer !', 'امسح أول متجر لتبدأ!');
    final lv = levelInfo();
    final next = lv['next'] as int?;
    if (next != null) {
      final left = next - (lv['visits'] as int);
      if (left <= 2) return tr('Encore $left visite${left > 1 ? 's' : ''} pour monter de niveau !', 'بقي $left زيارة لترقية مستواك!');
    }
    if (store.unread > 0) return tr('Vous avez des notifications non lues', 'لديك إشعارات غير مقروءة');
    const idle = [
      ('Prêt à gagner des points aujourd\'hui ?', 'جاهز لكسب نقاط اليوم؟'),
      ('N\'oubliez pas de montrer votre QR !', 'لا تنسَ إظهار رمزك!'),
      ('Découvrez les offres du moment dans l\'onglet Offres.', 'اكتشف العروض الحالية في تبويب العروض.'),
    ];
    final pick = idle[rnd.nextInt(idle.length)];
    return tr(pick.$1, pick.$2);
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message ?? _autoMessage();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (widget.bubble)
        TweenAnimationBuilder<double>(
          key: ValueKey(msg),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      AnimatedBuilder(
        animation: Listenable.merge([_float, _blink]),
        builder: (_, child) {
          final bob = sin(_float.value * pi) * 6;
          return Transform.translate(offset: Offset(0, -bob), child: Transform.scale(scaleY: 1 - _blink.value * 0.08, child: child));
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(alignment: Alignment.bottomCenter, children: [
            Positioned(
              bottom: 0,
              child: AnimatedBuilder(
                animation: _float,
                builder: (_, __) => Container(
                  width: widget.size * (0.55 - 0.05 * sin(_float.value * pi)),
                  height: widget.size * 0.1,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
            Padding(padding: EdgeInsets.only(bottom: widget.size * 0.12), child: Image.asset('robot.png', width: widget.size * 0.85, fit: BoxFit.contain)),
          ]),
        ),
      ),
    ]);
  }
}

/// Petite version pour un coin d'écran : touchez-la pour afficher un conseil.
class MascotPeek extends StatefulWidget {
  const MascotPeek({super.key});
  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek> {
  bool open = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => open = !open),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomRight,
          child: open ? const LivingMascot(size: 72) : const LivingMascot(size: 56, bubble: false),
        ),
      );
}
