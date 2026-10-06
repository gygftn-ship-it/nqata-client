import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'extras.dart';
import 'mascot.dart';
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

/// Anneau de compte à rebours autour du QR (passe à l'ambre avant le renouvellement).
class _RingPainter extends CustomPainter {
  final double t; // 1 → 0
  _RingPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final track = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = Colors.white24;
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..color = t < 0.18 ? Colors.redAccent : brandYellow;
    canvas.drawArc(r, 0, 2 * pi, false, track);
    canvas.drawArc(r, -pi / 2, 2 * pi * t, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
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

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? tr('Bonjour', 'صباح الخير') : h < 18 ? tr('Bon après-midi', 'طاب يومك') : tr('Bonsoir', 'مساء الخير');
  }

  void _openShop(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s)));

  Widget _title(String t, {VoidCallback? more}) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          if (more != null) TextButton(onPressed: more, child: Text(tr('Voir tout', 'عرض الكل'))),
        ]),
      );

  Widget _qrCard() => AnimatedBuilder(
        animation: pulse,
        builder: (_, child) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight]),
            boxShadow: [BoxShadow(color: brandLight.withOpacity(0.25 + 0.2 * pulse.value), blurRadius: 24 + 16 * pulse.value, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: tokenN,
          builder: (_, token, __) => Column(children: [
            Row(children: [
              Image.asset('coin.png', width: 28, height: 28),
              const SizedBox(width: 8),
              Text(tr('Mon QR personnel', 'رمزي الشخصي'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(icon: const NIcon('refresh', color: Colors.white70), tooltip: tr('Renouveler', 'تجديد'), onPressed: _restart),
            ]),
            const SizedBox(height: 4),
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
                    builder: (_, v, __) => CustomPaint(size: const Size(252, 252), painter: _RingPainter(token.isEmpty ? 0 : v)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
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
            Text(tr('Touchez le QR pour l\'agrandir · renouvelé toutes les 45 s', 'المس الرمز لتكبيره · يتجدد كل 45 ثانية'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 12),
            Pressable(
              onTap: () {
                if (store.code.isEmpty) return;
                Clipboard.setData(ClipboardData(text: store.code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Code copié', 'تم نسخ الرمز'))));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text(tr('Mon code client · à donner si le scan ne marche pas', 'رمز الزبون · أعطه إن لم ينجح المسح'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(store.code.isEmpty ? '······' : store.code, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 6, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    const NIcon('copy', color: Colors.white70, size: 18),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      );

  Widget _action(String icon, String label, List<Color> colors, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: colors), boxShadow: [BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]),
              child: NIcon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final theme = Theme.of(context);
          final lv = levelInfo();
          final next = lv['next'] as int?;
          final progress = next == null ? 1.0 : (((lv['visits'] as int) - (lv['from'] as int)) / (next - (lv['from'] as int))).clamp(0.0, 1.0).toDouble();
          final deals = store.offers.take(8).toList();
          final favs = store.shops.where((s) => store.favs.contains('${s['id']}')).toList();
          final acts = store.txs.where((t) => t['undone'] != true).take(4).toList();
          final ready = store.rewardsReady;
          return Stack(children: [
            RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
              FadeSlideIn(
                child: Row(children: [
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
                      Text(_greeting(), style: theme.textTheme.bodyMedium),
                      Text(store.name.isEmpty ? '…' : store.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  Pressable(
                    onTap: () => Navigator.push(context, smoothRoute(const NotificationsPage())),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Badge(
                        isLabelVisible: store.unread > 0,
                        label: Text('${store.unread}'),
                        child: AnimatedBuilder(
                          animation: bell,
                          builder: (_, child) => Transform.rotate(angle: store.unread > 0 && bell.value < 0.15 ? sin(bell.value / 0.15 * pi * 6) * 0.3 : 0, child: child),
                          child: const NIcon('bell', size: 30),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(index: 1, child: _qrCard()),
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 2,
                child: Row(children: [
                  _action('wallet', tr('Portefeuille', 'المحفظة'), const [Color(0xFF0B5F50), Color(0xFF14B8A6)], () => widget.goTo(2)),
                  _action('pin', tr('Carte', 'الخريطة'), const [Color(0xFF1D4ED8), Color(0xFF60A5FA)], () => widget.goTo(1)),
                  _action('tag', tr('Offres', 'العروض'), const [Color(0xFFBE185D), Color(0xFFF472B6)], () => widget.goTo(3)),
                  _action('history', tr('Historique', 'السجل'), const [Color(0xFF7C3AED), Color(0xFFA78BFA)], () => Navigator.push(context, smoothRoute(const HistoryPage()))),
                ]),
              ),
              if (ready.isNotEmpty) ...[
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 3,
                  child: Pressable(
                    onTap: () => widget.goTo(2),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade600])),
                      child: Row(children: [
                        AnimatedBuilder(animation: pulse, builder: (_, __) => Transform.scale(scale: 1 + 0.15 * pulse.value, child: const NIcon('gift', size: 36, color: Colors.black87, accent: Colors.white))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr('Une récompense vous attend !', 'مكافأة بانتظارك!'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            Text('${ready.join(', ')} · ${tr('montrez votre code au commerçant', 'أظهر رمزك للتاجر')}', style: const TextStyle(color: Colors.black87, fontSize: 12)),
                          ]),
                        ),
                        const NIcon('chevron', color: Colors.black54),
                      ]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (store.streakWeeks > 0)
                FadeSlideIn(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const NIcon('bolt', color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('${store.streakWeeks} semaine(s) de suite avec une visite !', '${store.streakWeeks} أسبوع متتالٍ بزيارة!'), style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              FadeSlideIn(
                index: 4,
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const NIcon('coin', color: brandLight),
                        AnimatedCount(store.total, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        Text('${tr('points', 'نقطة')} · ${store.wallet.length} ${tr('commerce(s)', 'متجر')}', style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pressable(
                      onTap: () => widget.goTo(4),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          NIcon('trophy', size: 28, color: lv['color'] as Color),
                          Text('${tr('Membre', 'عضو')} ${lv['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: v, minHeight: 6, color: lv['color'] as Color)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              if (deals.isNotEmpty) ...[
                _title(tr('Offres du moment', 'عروض الساعة'), more: () => widget.goTo(3)),
                SizedBox(
                  height: 96,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (var i = 0; i < deals.length; i++)
                      Pressable(
                        onTap: () {
                          final s = store.shops.where((x) => x['id'] == deals[i]['shop_id']).toList();
                          if (s.isNotEmpty) _openShop(s.first);
                        },
                        child: Container(
                          width: 230,
                          margin: const EdgeInsetsDirectional.only(end: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: cardGrads[i % 4])),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${deals[i]['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${(deals[i]['shops'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ],
              _title(tr('Mes favoris', 'مفضلتي')),
              if (favs.isEmpty)
                Text(tr('Touchez l’étoile sur la fiche d’un commerce pour le retrouver ici.', 'المس النجمة في صفحة المتجر لتجده هنا.'), style: const TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 92,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final s in favs)
                      Pressable(
                        onTap: () => _openShop(s),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 14),
                          child: Column(children: [
                            ShopLogo(shop: s, size: 58),
                            const SizedBox(height: 4),
                            SizedBox(width: 72, child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                          ]),
                        ),
                      ),
                  ]),
                ),
              _title(tr('Activité récente', 'النشاط الأخير'), more: () => Navigator.push(context, smoothRoute(const HistoryPage()))),
              if (acts.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Aucune visite pour le moment. Montrez votre QR chez un commerçant partenaire !', 'لا زيارات بعد. اعرض رمزك عند تاجر شريك!'), style: const TextStyle(color: Colors.grey))),
              for (var i = 0; i < acts.length; i++)
                FadeSlideIn(
                  index: i,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: acts[i]['type'] == 'reward' ? Colors.amber : Colors.green, child: NIcon(acts[i]['type'] == 'reward' ? 'gift' : 'add', color: Colors.white)),
                    title: Text('${acts[i]['shop'] ?? ''}'),
                    subtitle: Text(fmtDate(acts[i]['at'] as String?)),
                    trailing: Text('${(acts[i]['amount'] as int) > 0 ? '+' : ''}${acts[i]['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ]),
            ),
            const PositionedDirectional(end: 16, bottom: 8, child: MascotPeek()),
          ]);
        },
      );
}
