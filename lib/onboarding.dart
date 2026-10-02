import 'package:flutter/material.dart';
import 'nicons.dart';
import 'main.dart';
import 'tabs.dart';

/// Écrans de bienvenue (3 étapes) au premier lancement.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
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

  Widget _slide((String, String, String, String, String) s) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              child: NIcon(s.$1, size: 96, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(tr(s.$2, s.$3), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(tr(s.$4, s.$5), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
                    TextButton(onPressed: store.finishOnboarding, child: Text(tr('Passer', 'تخطي'), style: const TextStyle(color: Colors.white70))),
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
                          : store.finishOnboarding(),
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
