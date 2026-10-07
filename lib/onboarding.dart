import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'nicons.dart';
import 'profile.dart'; // coverThemes
import 'tabs.dart';

const _tutoKey = 'tuto_seen';

/// Affiche le tutoriel une seule fois (au premier lancement de l'app sur ce téléphone).
Future<void> maybeShowTutorial(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_tutoKey) ?? false) return;
  await p.setBool(_tutoKey, true); // marqué dès l'affichage : il ne reviendra pas
  if (!context.mounted) return;
  await Navigator.push(context, smoothRoute(const OnboardingPage()));
}

/// Tutoriel de bienvenue. Réutilisable : Navigator.push(context, smoothRoute(const OnboardingPage())).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final pc = PageController();
  int page = 0;

  static final _pages = [
    ('qr', 'Présentez votre QR', 'اعرض رمز QR', 'À chaque visite, montrez le QR de l\'accueil au commerçant pour gagner des points.', 'في كل زيارة، اعرض رمز QR الموجود في الرئيسية للتاجر لتكسب النقاط.'),
    ('wallet', 'Une carte par commerce', 'بطاقة لكل متجر', 'Retrouvez vos points, votre progression et vos transactions dans le portefeuille.', 'تابع نقاطك وتقدمك ومعاملاتك داخل المحفظة.'),
    ('gift', 'Débloquez des récompenses', 'افتح المكافآت', 'Quand vous atteignez le seuil d\'un commerce, votre récompense est prête à être utilisée.', 'عندما تبلغ حد المتجر، تصبح مكافأتك جاهزة للاستخدام.'),
    ('groups', 'Parrainez vos amis', 'رشّح أصدقاءك', 'Partagez votre code : quand votre ami visite un commerce, vous gagnez tous les deux des points.', 'شارك رمزك: عندما يزور صديقك متجرًا، تكسبان معًا نقاطًا.'),
  ];

  @override
  void dispose() { pc.dispose(); super.dispose(); }

  bool get last => page == _pages.length - 1;

  void _next() {
    if (last) {
      Navigator.pop(context);
    } else {
      pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  Widget _art(String icon) => Center(
        child: FadeSlideIn(
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 250, height: 250, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10)),
            Container(width: 180, height: 180, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12)),
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(36), boxShadow: [BoxShadow(color: brandYellow.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 12))]),
              child: NIcon(icon, size: 62, color: Colors.black87, accent: Colors.white),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cv = coverThemes[store.coverTheme % coverThemes.length];
    final theme = Theme.of(context);
    final p = _pages[page];
    return Scaffold(
      backgroundColor: cv.$4,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cv.$3, cv.$4])),
          child: Column(children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 12, 0),
                child: Row(children: [
                  const Expanded(child: Text('NQATA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 4))),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(onPressed: last ? null : () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Colors.white70), child: Text(tr('Passer', 'تخطي'))),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pc,
                itemCount: _pages.length,
                onPageChanged: (i) { HapticFeedback.selectionClick(); setState(() => page = i); },
                itemBuilder: (_, i) => _art(_pages[i].$1),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(page),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(p.$2, p.$3), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : -0.4)),
                      const SizedBox(height: 10),
                      SizedBox(height: 66, child: Text(tr(p.$4, p.$5), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: theme.colorScheme.onSurface.withOpacity(0.62)))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: page == i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: page == i ? brandLight : theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _next, child: Text(last ? tr('Commencer', 'ابدأ') : tr('Suivant', 'التالي')))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
