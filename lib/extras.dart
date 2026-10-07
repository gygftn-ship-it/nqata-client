import 'dart:math';
import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'tabs.dart';
import 'style.dart';
import 'profile.dart' show supportEmail; // adresse du support, définie dans profile.dart
import 'package:url_launcher/url_launcher.dart';

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
    ('Comment supprimer mon compte ?', 'كيف أحذف حسابي؟', 'Dans Profil › Paramètres, touchez « Supprimer mon compte ». Vos données sont effacées définitivement.', 'في الملف الشخصي › الإعدادات، المس «حذف حسابي». تُحذف بياناتك نهائيًا.'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(children: [
              Text(tr('Une autre question ?', 'سؤال آخر؟'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, smoothRoute(const SupportChatPage())),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: Text(tr('Contacter le support', 'تواصل مع الدعم')),
              ),
            ]),
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

// ---------- Support : chat qui envoie un e-mail à l'équipe ----------
class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});
  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final msgs = <(bool, String)>[]; // (envoyé par le client ?, texte)
  bool sending = false;

  @override
  void initState() {
    super.initState();
    msgs.add((false, tr('Bonjour ! Écrivez votre question ou votre problème : notre équipe vous répondra par e-mail.', 'مرحبًا! اكتب سؤالك أو مشكلتك وسيردّ عليك فريقنا عبر البريد الإلكتروني.')));
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    HapticFeedback.selectionClick();
    setState(() {
      sending = true;
      msgs.add((true, text));
      input.clear();
    });
    _toEnd();
    final body = '$text\n\n—\n${tr('Client', 'الزبون')} : ${store.name}\nCode : ${store.code}\nE-mail : ${store.email}';
    final uri = Uri.parse('mailto:$supportEmail?subject=${Uri.encodeComponent('Support Nqata')}&body=${Uri.encodeComponent(body)}');
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok) Clipboard.setData(const ClipboardData(text: supportEmail));
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      sending = false;
      msgs.add((
        false,
        ok
            ? tr('Merci ! Vous recevrez une réponse de notre équipe par e-mail. Si votre application e-mail vient de s\'ouvrir, appuyez sur « Envoyer » pour nous transmettre votre message.',
                'شكرًا! ستصلك إجابة فريقنا عبر البريد الإلكتروني. إذا فُتح تطبيق البريد، اضغط «إرسال» لإرسال رسالتك.')
            : tr('Aucune application e-mail trouvée. Écrivez-nous à $supportEmail (adresse copiée) : nous vous répondrons par e-mail.',
                'لم يتم العثور على تطبيق بريد. راسلنا على $supportEmail (تم نسخ العنوان) وسنردّ عليك عبر البريد.'),
      ));
    });
    _toEnd();
  }

  Widget _bubble(bool me, String t) => Align(
        alignment: me ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: me ? brandYellow : nTint(context), borderRadius: BorderRadius.circular(18)),
          child: Text(t, style: TextStyle(fontSize: 15, height: 1.35, color: me ? Colors.black87 : nInk(context))),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Support', 'الدعم'))),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _bubble(msgs[i].$1, msgs[i].$2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: tr('Votre message…', 'رسالتك…'),
                      filled: true,
                      fillColor: nTint(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: tr('Envoyer', 'إرسال'),
                  child: Material(
                    color: brandYellow,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(width: 50, height: 50, child: Icon(Icons.send_rounded, color: Colors.black87, size: 22)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}
