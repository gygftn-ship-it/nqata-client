import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'extras.dart';
import 'main.dart';
import 'notifs.dart';
import 'wallet.dart';

// ---------- Utilitaires animés ----------
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, this.index = 0, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + 60 * (index > 8 ? 8 : index)),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch)),
      );
}

class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount(this.value, {super.key, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}', style: style),
      );
}

String fmtDate(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.parse(iso).toLocal();
  return '${d.day}/${d.month} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const cardGrads = [
  [Color(0xFF0B5F50), Color(0xFF14B8A6)],
  [Color(0xFF3B0764), Color(0xFFEC4899)],
  [Color(0xFF7C2D12), Color(0xFFF59E0B)],
  [Color(0xFF0F172A), Color(0xFF3B82F6)],
];

// ---------- 1. Accueil ----------
class HomeTab extends StatefulWidget {
  final void Function(int) goTo;
  const HomeTab({super.key, required this.goTo});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  String token = '';
  String? qrError;
  Timer? timer;

  Future<void> _token() async {
    try {
      final t = await store.sb.rpc('new_qr_token') as String;
      if (mounted) setState(() { token = t; qrError = null; });
    } catch (e) {
      if (mounted) setState(() { token = ''; qrError = errText(e); });
    }
  }

  void _restart() {
    timer?.cancel();
    _token();
    timer = Timer.periodic(const Duration(seconds: rotationSeconds), (_) { _token(); store.refresh(); });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // l'écran reste allumé pendant que le commerçant scanne
    _restart();
  }

  // Au retour dans l'app (écran verrouillé, autre app...), l'ancien QR est expiré : on en demande un neuf tout de suite.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restart();
      store.refresh();
    }
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); WakelockPlus.disable(); timer?.cancel(); super.dispose(); }

  String? _next() {
    String? best;
    var bestLeft = 1 << 30;
    for (final r in store.wallet) {
      final s = r['shops'] as Map?;
      if (s == null) continue;
      final t = (s['reward_threshold'] as int?) ?? 100;
      final left = t - (r['points'] as int) % t;
      if (left < bestLeft) { bestLeft = left; best = '${s['name']}'; }
    }
    return best == null ? null : '$bestLeft ${tr('points avant une récompense chez', 'نقطة قبل مكافأة في')} $best';
  }

  Widget _stat(BuildContext context, IconData icon, int value, String label, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Icon(icon, color: brandLight, size: 30),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedCount(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final next = _next();
          final offer = store.offers.isEmpty ? null : store.offers.first;
          final acts = store.activity.where((a) => a['undone_at'] == null).take(3).toList();
          final theme = Theme.of(context);
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              FadeSlideIn(
                child: Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: brandDark, child: Text(store.name.isEmpty ? '?' : store.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('Bonjour', 'مرحبًا'), style: theme.textTheme.bodyMedium),
                      Text(store.name.isEmpty ? '…' : store.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  IconButton(
                    icon: Badge(isLabelVisible: store.unread > 0, label: Text('${store.unread}'), child: const Icon(Icons.notifications_rounded, size: 28)),
                    onPressed: () => Navigator.push(context, smoothRoute(const NotificationsPage())),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight]),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Text(tr('Mon QR personnel', 'رمزي الشخصي'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: token.isNotEmpty
                            ? QrImageView(key: ValueKey(token), data: token, size: 220)
                            : qrError != null
                                ? SizedBox(
                                    key: const ValueKey('e'),
                                    width: 220,
                                    height: 220,
                                    child: Center(
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.qr_code_2, size: 48, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(qrError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                                        TextButton(onPressed: _restart, child: Text(tr('Réessayer', 'إعادة المحاولة'))),
                                      ]),
                                    ),
                                  )
                                : const SizedBox(key: ValueKey('w'), width: 220, height: 220, child: Center(child: CircularProgressIndicator())),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 220,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(token),
                        tween: Tween(begin: 1, end: 0),
                        duration: const Duration(seconds: rotationSeconds),
                        builder: (_, v, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Colors.white24, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(tr('Le QR change toutes les 45 s', 'يتغير الرمز كل 45 ثانية'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (store.code.isEmpty) return;
                        Clipboard.setData(ClipboardData(text: store.code));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Code copié', 'تم نسخ الرمز'))));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          Text(tr('Mon code client', 'رمز الزبون'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(store.code.isEmpty ? '······' : store.code, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 6, fontFamily: 'monospace')),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(tr('À donner au commerçant si le scan ne marche pas', 'أعطه للتاجر إن لم ينجح المسح'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 2,
                child: Row(children: [
                  Expanded(child: _stat(context, Icons.stars_rounded, store.total, tr('Points', 'نقاط'))),
                  const SizedBox(width: 12),
                  Expanded(child: _stat(context, Icons.credit_card_rounded, store.wallet.length, tr('Cartes', 'بطاقات'), onTap: () => widget.goTo(2))),
                ]),
              ),
              if (store.rewardsReady.isNotEmpty) ...[
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 3,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Text('🎁', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${tr('Récompense disponible chez', 'مكافأة متاحة في')} ${store.rewardsReady.join(', ')}. ${tr('Montrez votre code au commerçant.', 'أظهر رمزك للتاجر.')}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
              if (next != null) ...[
                const SizedBox(height: 12),
                FadeSlideIn(index: 3, child: Row(children: [const Icon(Icons.emoji_events_rounded, color: Colors.amber), const SizedBox(width: 8), Expanded(child: Text(next))])),
              ],
              if (offer != null) ...[
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 4,
                  child: InkWell(
                    onTap: () => widget.goTo(3),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: cardGrads[2])),
                      child: Row(children: [
                        const Icon(Icons.local_offer_rounded, color: Colors.white, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${offer['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${(offer['shops'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text(tr('Activité récente', 'النشاط الأخير'), style: theme.textTheme.titleMedium)),
                TextButton(onPressed: () => Navigator.push(context, smoothRoute(const HistoryPage())), child: Text(tr('Voir tout', 'عرض الكل'))),
              ]),
              if (acts.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(tr('Aucune visite pour le moment', 'لا زيارات حتى الآن'))),
              for (final a in acts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('${(a['shops'] as Map?)?['name'] ?? ''}'),
                  subtitle: Text(fmtDate(a['created_at'] as String?)),
                  trailing: Text('+${a['points']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
          );
        },
      );
}

// ---------- 2. Carte : voir map.dart ----------

// ---------- 3. Cartes de fidélité (style carte bancaire virtuelle) ----------
class FlipCard extends StatefulWidget {
  final Widget front, back;
  const FlipCard({super.key, required this.front, required this.back});
  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> {
  bool flipped = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => flipped = !flipped),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: flipped ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          builder: (_, v, __) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(pi * v),
            child: v > 0.5
                ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(pi), child: widget.back)
                : widget.front,
          ),
        ),
      );
}

class _LoyaltyCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<Color> grad;
  const _LoyaltyCard({required this.row, required this.grad});

  @override
  Widget build(BuildContext context) {
    final shop = (row['shops'] as Map?) ?? {};
    final pts = row['points'] as int;
    final thr = (shop['reward_threshold'] as int?) ?? 100;
    final deco = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 12))],
    );
    const white = TextStyle(color: Colors.white);
    const dim = TextStyle(color: Colors.white70);
    Widget circle(double s) => Container(width: s, height: s, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10));

    final front = AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: deco,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Positioned(right: -40, top: -40, child: circle(160)),
            Positioned(left: -50, bottom: -60, child: circle(180)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${shop['name'] ?? ''}', style: white.copyWith(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.contactless_rounded, color: Colors.white),
                ]),
                if (pts >= thr)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                    child: Text('🎁 ${pts ~/ thr} ${tr('récompense(s) disponible(s)', 'مكافأة متاحة')}', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                AnimatedCount(pts, style: white.copyWith(fontSize: 44, fontWeight: FontWeight.bold)),
                Text(tr('points', 'نقطة'), style: dim),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: (pts % thr) / thr, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('•••• ${store.uid.substring(0, 4).toUpperCase()}', style: dim.copyWith(letterSpacing: 2)),
                  Text('${pts % thr} / $thr', style: dim),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );

    final back = AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: deco,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${shop['name'] ?? ''}', style: white.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text(tr('Prochaine récompense dans ${thr - pts % thr} points', 'المكافأة التالية بعد ${thr - pts % thr} نقطة'), style: white),
          const SizedBox(height: 6),
          Text('${tr('Une récompense tous les', 'مكافأة كل')} $thr ${tr('points', 'نقطة')}', style: dim),
          const SizedBox(height: 6),
          Text('${tr('Dernière visite', 'آخر زيارة')} : ${fmtDate(row['last_scan_at'] as String?)}', style: dim),
        ]),
      ),
    );
    return FlipCard(front: front, back: back);
  }
}

class CardsTab extends StatefulWidget {
  const CardsTab({super.key});
  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  final pc = PageController(viewportFraction: 0.88);
  @override
  void dispose() { pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final cards = [...store.wallet]..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.credit_card_rounded, size: 64, color: brandLight),
                  const SizedBox(height: 12),
                  Text(tr('Aucune carte pour le moment', 'لا توجد بطاقات حاليًا'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(tr('Présentez votre QR chez un commerçant partenaire pour recevoir votre première carte.', 'اعرض رمزك عند تاجر شريك لتحصل على أول بطاقة.'), textAlign: TextAlign.center),
                ]),
              ),
            );
          }
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(tr('Mes cartes', 'بطاقاتي'), style: Theme.of(context).textTheme.headlineSmall))),
            Expanded(
              child: PageView.builder(
                controller: pc,
                itemCount: cards.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 24),
                  child: Center(child: FadeSlideIn(index: i, child: _LoyaltyCard(row: cards[i], grad: cardGrads[i % cardGrads.length]))),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(tr('Touchez une carte pour la retourner', 'المس البطاقة لقلبها'), style: const TextStyle(color: Colors.grey))),
          ]);
        },
      );
}

// ---------- 4. Offres et bons plans ----------
class OffersTab extends StatelessWidget {
  const OffersTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Text(tr('Offres et bons plans', 'عروض وتخفيضات'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (store.offers.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucune offre pour le moment', 'لا توجد عروض حاليًا')))),
            for (var i = 0; i < store.offers.length; i++)
              FadeSlideIn(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: cardGrads[i % cardGrads.length])),
                  child: Row(children: [
                    const Icon(Icons.local_offer_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${store.offers[i]['title']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${(store.offers[i]['shops'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

// ---------- 5. Profil et paramètres ----------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _rename(BuildContext context) async {
    final c = TextEditingController(text: store.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Modifier mon nom', 'تعديل الاسم')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Enregistrer', 'حفظ'))),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) await store.rename(c.text.trim());
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Supprimer mon compte ?', 'حذف حسابي؟')),
        content: Text(tr('Votre compte, vos points et votre historique seront supprimés définitivement.', 'سيتم حذف حسابك ونقاطك وسجلك نهائيًا.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(d, true), child: Text(tr('Supprimer', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.deleteAccount();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
  }

  void _privacy(BuildContext context) => showDialog(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr('Confidentialité', 'الخصوصية')),
          content: Text(tr(
            'Nqata ne conserve que votre prénom ou pseudo et votre e-mail. Les commerçants voient seulement votre pseudo, votre solde et vos visites chez eux. Vous pouvez supprimer votre compte et toutes vos données à tout moment depuis cet écran.',
            'تحتفظ نقطة فقط باسمك أو لقبك وبريدك الإلكتروني. يرى التجار لقبك ورصيدك وزياراتك لديهم فقط. يمكنك حذف حسابك وكل بياناتك في أي وقت من هذه الشاشة.')),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 8),
          Center(child: CircleAvatar(radius: 40, backgroundColor: brandDark, child: Text(store.name.isEmpty ? '?' : store.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32)))),
          const SizedBox(height: 12),
          Center(child: Text(store.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          Center(child: Text(store.email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.edit), title: Text(tr('Modifier mon nom', 'تعديل الاسم')), onTap: () => _rename(context)),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr('Langue', 'اللغة')),
            trailing: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'fr', label: Text('FR')), ButtonSegment(value: 'ar', label: Text('عربي'))],
              selected: {lang},
              onSelectionChanged: (s) => store.setLang(s.first),
            ),
          ),
          ListTile(leading: const Icon(Icons.history), title: Text(tr('Historique', 'السجل')), onTap: () => Navigator.push(context, smoothRoute(const HistoryPage()))),
          ListTile(leading: const Icon(Icons.help_outline), title: Text(tr('Aide', 'المساعدة')), onTap: () => Navigator.push(context, smoothRoute(const HelpPage()))),
          const PinSettingsTile(),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(tr('Confidentialité', 'الخصوصية')), onTap: () => _privacy(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: Text(tr('Se déconnecter', 'تسجيل الخروج')), onTap: store.signOut),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(tr('Supprimer mon compte', 'حذف حسابي'), style: const TextStyle(color: Colors.red)),
            onTap: () => _delete(context),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('Nqata 0.1.0', style: TextStyle(color: Colors.grey))),
        ]),
      );
}
