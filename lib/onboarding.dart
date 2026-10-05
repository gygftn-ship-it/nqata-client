import 'package:flutter/material.dart';
import 'nicons.dart';
import 'main.dart';
import 'tabs.dart';

/// Écrans de bienvenue (3 étapes) au premier lancement.
class OnboardingPage extends StatefulWidget {
  final bool replay; // true : rouvert depuis le Profil, ne relance pas l'inscription
  const OnboardingPage({super.key, this.replay = false});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final pc = PageController();
  int page = 0;

  static const slides = [
    ('qr', 'Une seule carte pour tous vos commerces', 'بطاقة واحدة لكل محلاتك', 'Présentez votre QR et gagnez des points à chaque visite.', 'اعرض رمزك واكسب نقاطًا في كل زيارة.'),
    ('gift', 'Des récompenses qui vous attendent', 'مكافآت بانتظارك', 'Suivez vos points commerce par commerce et débloquez des cadeaux.', 'تابع نقاطك في كل متجر واكسب هدايا.'),
    ('pin', 'Offres et commerces près de vous', 'عروض ومحلات قريبة منك', 'Trouvez les commerces partenaires et profitez des bons plans.', 'اكتشف المحلات الشريكة واستفد من العروض.'),
  ];

  @override
  void dispose() { pc.dispose(); super.dispose(); }

  Widget _slide((String, String, String, String) s) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FadeSlideIn(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Text(tr(s.$3, s.$4), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF15120B), fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(index: 1, child: Image.asset('robot.png', height: 180)),
          const SizedBox(height: 24),
          Text(tr(s.$1, s.$2), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight])),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    TextButton(onPressed: () => store.setLang('fr'), child: Text('FR', style: TextStyle(color: Colors.white, fontWeight: lang == 'fr' ? FontWeight.bold : FontWeight.normal))),
                    TextButton(onPressed: () => store.setLang('ar'), child: Text('عربي', style: TextStyle(color: Colors.white, fontWeight: lang == 'ar' ? FontWeight.bold : FontWeight.normal))),
                    const Spacer(),
                    TextButton(onPressed: () => widget.replay ? Navigator.pop(context) : store.finishOnboarding(), child: Text(tr(widget.replay ? 'Fermer' : 'Passer', widget.replay ? 'إغلاق' : 'تخطي'), style: const TextStyle(color: Colors.white70))),
                  ]),
                ),
                Expanded(child: PageView(controller: pc, onPageChanged: (i) => setState(() => page = i), children: [for (final s in slides) _slide(s)])),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.all(4),
                      width: page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: page == i ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandDark, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () => page < slides.length - 1
                          ? pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
                          : (widget.replay ? Navigator.pop(context) : store.finishOnboarding()),
                      child: Text(page < slides.length - 1 ? tr('Suivant', 'التالي') : tr('Commencer', 'ابدأ')),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
