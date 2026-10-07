import 'package:flutter/material.dart';
import 'home.dart'; // Pressable
import 'main.dart';
import 'nicons.dart';
import 'profile.dart'; // coverThemes
import 'referral.dart';

/// Bandeau promo du parrainage (carrousel avec points de pagination), à placer dans le portefeuille.
class ReferralBanner extends StatefulWidget {
  const ReferralBanner({super.key});
  @override
  State<ReferralBanner> createState() => _ReferralBannerState();
}

class _ReferralBannerState extends State<ReferralBanner> {
  final pc = PageController();
  int page = 0;

  @override
  void dispose() { pc.dispose(); super.dispose(); }

  Widget _badge(String icon) => Transform.rotate(
        angle: -0.2,
        child: Container(
          width: 70,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandYellow, Color(0xFFFF8A00)]),
            boxShadow: [BoxShadow(color: brandYellow.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: NIcon(icon, size: 32, color: Colors.black87, accent: Colors.white),
        ),
      );

  Widget _slide(Map<String, dynamic> s, List<Color> bg) => Pressable(
        onTap: () => Navigator.push(context, smoothRoute(const ReferralPage())),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 18, 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg)),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['top'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(s['bottom'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: s['mono'] == true ? 22 : 17, fontWeight: FontWeight.w600, letterSpacing: s['mono'] == true ? 4 : 0, fontFamily: s['mono'] == true ? 'monospace' : null)),
              ]),
            ),
            const SizedBox(width: 12),
            _badge(s['icon'] as String),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cv = coverThemes[store.coverTheme % coverThemes.length];
    final bg = [Color.lerp(cv.$3, Colors.white, 0.06)!, cv.$4];
    final slides = [
      {'icon': 'gift', 'top': tr('Invitez vos amis, gagnez des points', 'ادعُ أصدقاءك واكسب نقاطًا'), 'bottom': tr('Parrainez un ami, vous gagnez tous les deux', 'رشّح صديقًا وتكسبان معًا')},
      {'icon': 'share', 'top': tr('Votre code de parrainage', 'رمز الترشيح الخاص بك'), 'bottom': store.code.isEmpty ? '······' : store.code, 'mono': true},
    ];
    final ink = Theme.of(context).colorScheme.onSurface;
    return Column(children: [
      SizedBox(
        height: 108,
        child: PageView.builder(
          controller: pc,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) => _slide(slides[i], bg),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: page == i ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(color: ink.withOpacity(page == i ? 0.75 : 0.22), borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}
