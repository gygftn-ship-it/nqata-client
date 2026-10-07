import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

/// Enveloppe l'application : affiche l'écran de chargement au démarrage, puis le fait
/// disparaître en fondu. L'app (connexion ou accueil) se prépare déjà dessous pendant ce temps.
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => done = true);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: done,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchOutCurve: Curves.easeOut,
              child: done ? const SizedBox.shrink(key: ValueKey('gone')) : const SplashScreen(key: ValueKey('splash')),
            ),
          ),
        ),
      ]);
}

/// Écran de chargement : jaune Nqate, pièce, nom de l'app, slogan et barre de chargement.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Animation<double> _in(double a, double b, [Curve curve = Curves.easeOutCubic]) => CurvedAnimation(parent: c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final logo = _in(0.0, 0.55, Curves.easeOutBack);
    final name = _in(0.30, 0.75);
    final tag = _in(0.55, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // icônes de la barre d'état sombres sur le jaune
      child: Material(
        color: brandYellow,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -0.25), radius: 1.1, colors: [Color(0xFFFFE45C), brandYellow, Color(0xFFF2C300)], stops: [0, 0.55, 1]),
          ),
          child: SafeArea(
            child: Column(children: [
              const Spacer(flex: 5),
              // pièce dans un disque doux
              FadeTransition(
                opacity: _in(0.0, 0.35),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.55, end: 1).animate(logo),
                  child: Container(
                    width: 148,
                    height: 148,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.38),
                      border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                      boxShadow: [BoxShadow(color: brandDark.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 14))],
                    ),
                    child: Image.asset('coin.png', width: 92, height: 92, errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, size: 80, color: brandDark)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: name,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(name),
                  child: const Text('NQATE', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 7, color: brandDark, height: 1)),
                ),
              ),
              const SizedBox(height: 14),
              FadeTransition(
                opacity: tag,
                child: Text(tr('Vos points, partout !', 'نقاطك في كل مكان!'), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: brandDark.withOpacity(0.72), letterSpacing: lang == 'ar' ? 0 : 0.3)),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: tag,
                child: SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(minHeight: 4, color: brandDark, backgroundColor: brandDark.withOpacity(0.14)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ),
    );
  }
}
