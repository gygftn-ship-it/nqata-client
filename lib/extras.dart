import 'dart:math';
import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'tabs.dart';

// ---------- Historique complet : visites et récompenses utilisées ----------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> f = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final sc = await store.sb.from('scans').select('points, created_at, undone_at, shops(name)').eq('client_id', store.uid).order('created_at', ascending: false).limit(100);
    final rd = await store.sb.from('redemptions').select('points_cost, created_at, shops(name)').eq('client_id', store.uid).order('created_at', ascending: false).limit(100);
    final all = <Map<String, dynamic>>[
      for (final s in sc as List) {...Map<String, dynamic>.from(s as Map), 'type': 'visit'},
      for (final r in rd as List) {...Map<String, dynamic>.from(r as Map), 'type': 'reward'},
    ];
    all.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return all;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Historique', 'السجل'))),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: f,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(errText(snap.error!), textAlign: TextAlign.center),
                    TextButton(onPressed: () => setState(() => f = _load()), child: Text(tr('Réessayer', 'إعادة المحاولة'))),
                  ]),
                ),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) return Center(child: Text(tr('Aucune visite pour le moment', 'لا زيارات حتى الآن')));
            return ListView(children: [
              for (var i = 0; i < rows.length; i++)
                FadeSlideIn(
                  index: i,
                  child: ListTile(
                    leading: rows[i]['type'] == 'reward'
                        ? const CircleAvatar(backgroundColor: Colors.amber, child: NIcon('gift', color: Colors.black87))
                        : CircleAvatar(backgroundColor: rows[i]['undone_at'] != null ? Colors.grey : Colors.green, child: const NIcon('check', color: Colors.white)),
                    title: Text('${(rows[i]['shops'] as Map?)?['name'] ?? ''}'),
                    subtitle: Text(rows[i]['type'] == 'reward' ? tr('Récompense utilisée', 'مكافأة مستخدمة') : fmtDate(rows[i]['created_at'] as String?)),
                    trailing: rows[i]['type'] == 'reward'
                        ? Text('-${rows[i]['points_cost']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))
                        : rows[i]['undone_at'] != null
                            ? Text(tr('Annulé', 'ملغى'), style: const TextStyle(color: Colors.grey))
                            : Text('+${rows[i]['points']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ]);
          },
        ),
      );
}

// ---------- Aide ----------
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const faq = [
    ('Comment gagner des points ?', 'كيف أكسب نقاطًا؟', 'Présentez votre QR (ou donnez votre code client) au commerçant à chaque visite.', 'اعرض رمزك (أو أعطِ رمز الزبون) للتاجر في كل زيارة.'),
    ('Le commerçant n\'arrive pas à scanner', 'التاجر لا يستطيع المسح', 'Augmentez la luminosité, gardez l\'écran allumé sur l\'accueil, ou donnez-lui votre code client à 6 caractères.', 'ارفع سطوع الشاشة وأبقها مضاءة في الرئيسية، أو أعطه رمز الزبون المكوّن من 6 خانات.'),
    ('Mes points valent-ils partout ?', 'هل نقاطي صالحة في كل مكان؟', 'Non : chaque commerce a son propre programme. Vos cartes montrent vos points commerce par commerce.', 'لا: لكل متجر برنامجه الخاص. تُظهر بطاقاتك نقاطك في كل متجر.'),
    ('Comment utiliser une récompense ?', 'كيف أستخدم المكافأة؟', 'Quand votre carte affiche une récompense disponible, montrez votre code au commerçant : il la valide et déduit les points.', 'عندما تظهر مكافأة متاحة في بطاقتك، أظهر رمزك للتاجر ليؤكدها ويخصم النقاط.'),
    ('Comment supprimer mon compte ?', 'كيف أحذف حسابي؟', 'Dans Profil, touchez « Supprimer mon compte ». Vos données sont effacées définitivement.', 'في الملف الشخصي، المس «حذف حسابي». تُحذف بياناتك نهائيًا.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Aide', 'المساعدة'))),
        body: ListView(children: [
          for (final q in faq)
            ExpansionTile(
              title: Text(tr(q.$1, q.$2), style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(tr(q.$3, q.$4))],
            ),
        ]),
      );
}

// ---------- Confettis : récompense débloquée ----------
void showConfetti(BuildContext context, String shop) {
  HapticFeedback.heavyImpact();
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: child),
    pageBuilder: (c, _, __) {
      Future.delayed(const Duration(milliseconds: 3400), () {
        if (c.mounted && Navigator.of(c).canPop()) Navigator.of(c).pop();
      });
      return Material(color: Colors.transparent, child: _ConfettiOverlay(shop: shop));
    },
  );
}

class _ConfettiOverlay extends StatefulWidget {
  final String shop;
  const _ConfettiOverlay({required this.shop});
  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  final rnd = Random(7);
  late final parts = List.generate(70, (i) => [rnd.nextDouble(), 0.5 + rnd.nextDouble() * 0.7, rnd.nextDouble() * 6.28, 6 + rnd.nextDouble() * 6, i % 5.0]);

  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(c.value, parts)))),
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: c, curve: const Interval(0, 0.3, curve: Curves.elasticOut)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
const NIcon('gift', size: 88, color: Colors.white, accent: brandYellow),
              const SizedBox(height: 8),
              Text(tr('Récompense débloquée !', 'تم فتح مكافأة!'), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              if (widget.shop.isNotEmpty) Text(widget.shop, style: const TextStyle(color: Colors.white70, fontSize: 18)),
            ]),
          ),
        ),
      ]);
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<List<double>> parts;
  _ConfettiPainter(this.t, this.parts);
  static const colors = [Colors.amber, Colors.pink, Colors.teal, Colors.orange, Colors.purple];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final y = t * p[1] * (size.height + 60) - 30;
      final x = p[0] * size.width + sin(t * 6 + p[2]) * 24;
      final paint = Paint()..color = colors[p[4].toInt()].withOpacity((1 - t * 0.6).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[2] + t * 8);
      canvas.drawRect(Rect.fromLTWH(-p[3] / 2, -p[3] / 4, p[3], p[3] / 2), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
