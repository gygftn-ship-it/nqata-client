import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'extras.dart';
import 'main.dart';
import 'notifs.dart';
import 'profile.dart';
import 'shop.dart';
import 'tabs.dart';

/// Effet « pressé » : la carte rétrécit sous le doigt, avec une petite vibration.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapUp: (_) { setState(() => down = false); HapticFeedback.selectionClick(); widget.onTap?.call(); },
        onTapCancel: () => setState(() => down = false),
        child: AnimatedScale(scale: down ? 0.94 : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
      );
}

/// Anneau de compte à rebours autour du QR (passe au rouge avant le renouvellement).
class _RingPainter extends CustomPainter {
  final double t; // 1 → 0
  final Color track, arc;
  _RingPainter(this.t, {required this.track, required this.arc});
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final trackPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = track;
    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..color = t < 0.18 ? Colors.redAccent : arc;
    canvas.drawArc(r, 0, 2 * pi, false, trackPaint);
    canvas.drawArc(r, -pi / 2, 2 * pi * t, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.track != track || old.arc != arc;
}

class _QrFull extends StatelessWidget {
  final ValueNotifier<String> token;
  const _QrFull({required this.token});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: token,
            builder: (_, t, __) => Column(mainAxisSize: MainAxisSize.min, children: [
              t.isEmpty ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())) : QrImageView(data: t, size: min(MediaQuery.of(context).size.width - 48, 380.0)),
              const SizedBox(height: 24),
              Text(store.code, style: const TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 8, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text(tr('Montrez ce QR au commerçant', 'اعرض هذا الرمز للتاجر'), style: const TextStyle(color: Colors.black54)),
            ]),
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  final void Function(int) goTo;
  const HomeScreen({super.key, required this.goTo});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final tokenN = ValueNotifier<String>('');
  String? qrError;
  Timer? timer;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  late final AnimationController bell = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  Future<void> _token() async {
    try {
      final t = await store.sb.rpc('new_qr_token') as String;
      if (mounted) setState(() { tokenN.value = t; qrError = null; });
    } catch (e) {
      if (mounted) setState(() { tokenN.value = ''; qrError = errText(e); });
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

  // Au retour dans l'app, l'ancien QR est expiré : on en demande un neuf tout de suite.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _restart(); store.refresh(); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    timer?.cancel();
    pulse.dispose();
    bell.dispose();
    tokenN.dispose();
    super.dispose();
  }

  // ---------- Couleurs du thème ----------
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _tint => brandYellow.withOpacity(_dark ? 0.12 : 0.22); // fond « jaune pâle » des cartes
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _gold => _dark ? brandYellow : brandLight; // accent lisible sur fond pâle ou sombre

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? tr('Bonjour', 'صباح الخير') : h < 18 ? tr('Bon après-midi', 'طاب يومك') : tr('Bonsoir', 'مساء الخير');
  }

  void _openShop(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s)));

  // ---------- Morceaux d'interface ----------
  Widget _title(String t, {VoidCallback? more}) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2))),
          if (more != null) TextButton(onPressed: more, child: Text(tr('Voir tout', 'عرض الكل'))),
        ]),
      );

  /// Cloche mascotte : une image quand il y a des notifications non lues, une autre sinon.
  Widget _bell() {
    final has = store.unread > 0;
    return Semantics(
      button: true,
      label: tr('Notifications', 'الإشعارات'),
      child: Pressable(
        onTap: () => Navigator.push(context, smoothRoute(const NotificationsPage())),
        child: AnimatedBuilder(
          animation: bell,
          builder: (_, child) => Transform.rotate(angle: has && bell.value < 0.15 ? sin(bell.value / 0.15 * pi * 6) * 0.2 : 0, child: child),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Image.asset(has ? 'notif_new.png' : 'notif_none.png', key: ValueKey(has), width: 56, height: 56),
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> lv) => Row(children: [
        Pressable(
          onTap: () => widget.goTo(4),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [lv['color'] as Color, Colors.white, lv['color'] as Color])),
            child: CircleAvatar(radius: 24, backgroundColor: avatarColors[store.avatarColor % avatarColors.length], child: Text(store.name.isEmpty ? '?' : store.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting(), style: Theme.of(context).textTheme.bodyMedium),
            Text(store.name.isEmpty ? '…' : store.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
          ]),
        ),
        _bell(),
      ]);

  /// Grande carte du haut : solde de points + QR qui se renouvelle + code client.
  Widget _qrCard() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
        decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(28)),
        child: ValueListenableBuilder<String>(
          valueListenable: tokenN,
          builder: (_, token, __) => Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Mes points', 'نقاطي'), style: TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Image.asset('coin.png', width: 30, height: 30),
                    const SizedBox(width: 8),
                    AnimatedCount(store.total, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${tr('pts', 'نقطة')} · ${store.wallet.length} ${tr('commerce(s)', 'متجر')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: _ink.withOpacity(0.65)))),
                  ]),
                ]),
              ),
              IconButton(icon: NIcon('refresh', color: _ink.withOpacity(0.7), accent: _gold), tooltip: tr('Renouveler', 'تجديد'), onPressed: _restart),
            ]),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: token.isEmpty ? null : () { HapticFeedback.mediumImpact(); Navigator.push(context, smoothRoute(_QrFull(token: tokenN))); },
              child: SizedBox(
                width: 252,
                height: 252,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(token),
                    tween: Tween(begin: 1, end: 0),
                    duration: const Duration(seconds: rotationSeconds),
                    builder: (_, v, __) => CustomPaint(size: const Size(252, 252), painter: _RingPainter(token.isEmpty ? 0 : v, track: _ink.withOpacity(0.10), arc: _gold)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c)),
                      child: token.isNotEmpty
                          ? QrImageView(key: ValueKey(token), data: token, size: 196)
                          : qrError != null
                              ? SizedBox(
                                  key: const ValueKey('e'),
                                  width: 196,
                                  height: 196,
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const NIcon('qr', size: 44, color: Colors.grey),
                                    const SizedBox(height: 6),
                                    Text(qrError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                                    TextButton(onPressed: _restart, child: Text(tr('Réessayer', 'إعادة المحاولة'))),
                                  ]),
                                )
                              : const SizedBox(key: ValueKey('w'), width: 196, height: 196, child: Center(child: CircularProgressIndicator())),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Text(tr('Touchez le QR pour l\'agrandir · renouvelé toutes les 45 s', 'المس الرمز لتكبيره · يتجدد كل 45 ثانية'), textAlign: TextAlign.center, style: TextStyle(color: _ink.withOpacity(0.6), fontSize: 11)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Pressable(
                onTap: () {
                  if (store.code.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: store.code));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Code copié', 'تم نسخ الرمز'))));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: brandDark, borderRadius: BorderRadius.circular(18)),
                  child: Column(children: [
                    Text(tr('Mon code client · à donner si le scan ne marche pas', 'رمز الزبون · أعطه إن لم ينجح المسح'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(store.code.isEmpty ? '······' : store.code, style: const TextStyle(color: brandYellow, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 6, fontFamily: 'monospace')),
                      const SizedBox(width: 10),
                      const NIcon('copy', color: Colors.white70, size: 18),
                    ]),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );

  /// Icône ronde sur fond jaune pâle + libellé (comme la grille de services du modèle).
  Widget _action(String icon, String label, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _tint),
              child: NIcon(icon, size: 30, color: _ink, accent: _gold),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      );

  Widget _readyBanner(List<String> ready) => Pressable(
        onTap: () => widget.goTo(2),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade600])),
          child: Row(children: [
            AnimatedBuilder(animation: pulse, builder: (_, __) => Transform.scale(scale: 1 + 0.15 * pulse.value, child: const NIcon('gift', size: 40, color: Colors.black87, accent: Colors.white))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Une récompense vous attend !', 'مكافأة بانتظارك!'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${ready.join(', ')} · ${tr('montrez votre code au commerçant', 'أظهر رمزك للتاجر')}', style: const TextStyle(color: Colors.black87, fontSize: 12)),
              ]),
            ),
            const NIcon('chevron', color: Colors.black54),
          ]),
        ),
      );

  /// Bannières d'offres (défilement horizontal).
  Widget _offerBanners(List<Map<String, dynamic>> deals) => SizedBox(
        height: 150,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < deals.length; i++)
            Pressable(
              onTap: () {
                final s = store.shops.where((x) => x['id'] == deals[i]['shop_id']).toList();
                if (s.isNotEmpty) _openShop(s.first);
              },
              child: Container(
                width: 270,
                margin: const EdgeInsetsDirectional.only(end: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cardGrads[i % cardGrads.length])),
                child: Stack(children: [
                  PositionedDirectional(end: -16, bottom: -16, child: NIcon('tag', size: 120, color: Colors.white.withOpacity(0.14), accent: Colors.white.withOpacity(0.14))),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(20)),
                        child: Text('${(deals[i]['shops'] as Map?)?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                      Text('${deals[i]['title']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.15)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      );

  /// Favoris : pastilles rondes avec anneau doré (comme les « stories » du modèle).
  Widget _favsCard(List<Map<String, dynamic>> favs) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            NIcon('star', size: 24, color: _ink, accent: _gold),
            const SizedBox(width: 8),
            Text(tr('Mes favoris', 'مفضلتي'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (favs.isEmpty)
            Text(tr('Touchez l’étoile sur la fiche d’un commerce pour le retrouver ici.', 'المس النجمة في صفحة المتجر لتجده هنا.'), style: TextStyle(color: _ink.withOpacity(0.6)))
          else
            SizedBox(
              height: 96,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final s in favs)
                  Pressable(
                    onTap: () => _openShop(s),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [brandYellow, brandLight, brandYellow])),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.surface),
                            child: ClipOval(child: ShopLogo(shop: s, size: 54)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(width: 68, child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
              ]),
            ),
        ]),
      );

  /// Carte « niveau fidélité » (comme la bannière Yassir Plus du modèle).
  Widget _levelCard(Map<String, dynamic> lv, int? next, double progress) {
    final c = lv['color'] as Color;
    return Pressable(
      onTap: () => widget.goTo(4),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.18)),
            child: NIcon('trophy', size: 34, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Votre niveau fidélité', 'مستوى ولائك'), style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 12)),
              Text('${tr('Membre', 'عضو')} ${lv['name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: v, minHeight: 7, color: c, backgroundColor: _ink.withOpacity(0.10))),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? tr('Niveau maximum atteint', 'وصلت لأعلى مستوى') : '${next - (lv['visits'] as int)} ${tr('visites avant le prochain niveau', 'زيارة للمستوى التالي')}',
                style: TextStyle(fontSize: 12, color: _ink.withOpacity(0.7)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          NIcon('chevron', color: _ink, accent: _gold),
        ]),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> a) {
    final reward = a['type'] == 'reward';
    final amount = a['amount'] as int;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: reward ? brandYellow : Theme.of(context).colorScheme.surface),
            child: NIcon(reward ? 'gift' : 'add', size: 22, color: reward ? Colors.black87 : _ink, accent: reward ? Colors.white : _gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['shop'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(fmtDate(a['at'] as String?), style: TextStyle(fontSize: 12, color: _ink.withOpacity(0.6))),
            ]),
          ),
          Text('${amount > 0 ? '+' : ''}$amount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final lv = levelInfo();
          final next = lv['next'] as int?;
          final progress = next == null ? 1.0 : (((lv['visits'] as int) - (lv['from'] as int)) / (next - (lv['from'] as int))).clamp(0.0, 1.0).toDouble();
          final deals = store.offers.take(8).toList();
          final favs = store.shops.where((s) => store.favs.contains('${s['id']}')).toList();
          final acts = store.txs.where((t) => t['undone'] != true).take(4).toList();
          final ready = store.rewardsReady;
          final divider = Divider(height: 28, color: Theme.of(context).colorScheme.outlineVariant);
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              FadeSlideIn(child: _header(lv)),
              const SizedBox(height: 16),
              FadeSlideIn(index: 1, child: _qrCard()),
              const SizedBox(height: 22),
              FadeSlideIn(
                index: 2,
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _action('wallet', tr('Portefeuille', 'المحفظة'), () => widget.goTo(2)),
                    _action('pin', tr('Carte', 'الخريطة'), () => widget.goTo(1)),
                    _action('tag', tr('Offres', 'العروض'), () => widget.goTo(3)),
                    _action('history', tr('Historique', 'السجل'), () => Navigator.push(context, smoothRoute(const HistoryPage()))),
                  ]),
                  divider,
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _action('gift', tr('Récompenses', 'المكافآت'), () => widget.goTo(2)),
                    _action('trophy', tr('Mon niveau', 'مستواي'), () => widget.goTo(4)),
                    _action('help', tr('Aide', 'المساعدة'), () => Navigator.push(context, smoothRoute(const HelpPage()))),
                    _action('user', tr('Profil', 'الملف'), () => widget.goTo(4)),
                  ]),
                ]),
              ),
              if (ready.isNotEmpty) ...[
                const SizedBox(height: 20),
                FadeSlideIn(index: 3, child: _readyBanner(ready)),
              ],
              if (deals.isNotEmpty) ...[
                _title(tr('Meilleures offres', 'أفضل العروض'), more: () => widget.goTo(3)),
                _offerBanners(deals),
              ],
              const SizedBox(height: 22),
              FadeSlideIn(index: 4, child: _favsCard(favs)),
              const SizedBox(height: 14),
              FadeSlideIn(index: 5, child: _levelCard(lv, next, progress)),
              _title(tr('Activité récente', 'النشاط الأخير'), more: () => Navigator.push(context, smoothRoute(const HistoryPage()))),
              if (acts.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Aucune visite pour le moment. Montrez votre QR chez un commerçant partenaire !', 'لا زيارات بعد. اعرض رمزك عند تاجر شريك!'), style: const TextStyle(color: Colors.grey))),
              for (var i = 0; i < acts.length; i++) FadeSlideIn(index: i, child: _activityTile(acts[i])),
            ]),
          );
        },
      );
}
