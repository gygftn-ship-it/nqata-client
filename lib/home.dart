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

/// Effet « pressé » : l'élément rétrécit légèrement sous le doigt, avec une petite vibration.
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
        child: AnimatedScale(scale: down ? 0.97 : 1, duration: const Duration(milliseconds: 100), curve: Curves.easeOut, child: widget.child),
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
    final trackPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = track;
    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = t < 0.18 ? Colors.redAccent : arc;
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final tokenN = ValueNotifier<String>('');
  String? qrError;
  Timer? timer;

  // Bannières : toutes les images du dossier (bucket) Supabase Storage « banners », triées par nom
  List<String> banners = [];
  List<String> bannerNames = []; // noms de fichiers (même ordre) : peuvent contenir le titre et le sous-titre
  final bannerPc = PageController(viewportFraction: 0.92);
  int bannerIdx = 0;
  Timer? bannerTimer;
  bool bannersLoading = true;
  static const _imgExt = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

  Future<void> _loadBanners() async {
    try {
      final bucket = store.sb.storage.from('banners');
      final files = await bucket.list();
      final names = [
        for (final f in files)
          if (_imgExt.any((e) => f.name.toLowerCase().endsWith(e))) f.name,
      ];
      final urls = [for (final n in names) bucket.getPublicUrl(n)];
      if (!mounted) return;
      setState(() { banners = urls; bannerNames = names; bannersLoading = false; if (bannerIdx >= urls.length) bannerIdx = 0; });
      _startBannerTimer();
    } catch (_) {
      // dossier absent ou hors connexion : le carrousel reste simplement masqué
      if (mounted) setState(() { banners = []; bannerNames = []; bannersLoading = false; });
    }
  }

  void _startBannerTimer() {
    bannerTimer?.cancel();
    if (banners.length < 2) return;
    bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !bannerPc.hasClients || banners.length < 2) return;
      bannerPc.animateToPage((bannerIdx + 1) % banners.length, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

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
    _loadBanners();
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
    bannerTimer?.cancel();
    bannerPc.dispose();
    tokenN.dispose();
    super.dispose();
  }

  // ---------- Couleurs et style (sobre, clair) ----------
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _card => _dark ? const Color(0xFF181611) : Colors.white;
  Color get _line => _ink.withOpacity(_dark ? 0.14 : 0.10); // filets et contours fins
  Color get _muted => _ink.withOpacity(0.62);
  Color get _gold => _dark ? brandYellow : brandLight; // accent des icônes
  Color get _link => _dark ? brandYellow : const Color(0xFF8A6500); // texte cliquable : contraste suffisant sur blanc
  bool get _ar => lang == 'ar';
  String _caps(String t) => _ar ? t : t.toUpperCase(); // pas de majuscules ni d'espacement en arabe (casse la liaison des lettres)
  double get _ls => _ar ? 0 : 1.2;

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? tr('Bonjour', 'صباح الخير') : h < 18 ? tr('Bon après-midi', 'طاب يومك') : tr('Bonsoir', 'مساء الخير');
  }

  void _openShop(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s)));

  // ---------- Morceaux d'interface ----------
  /// Carte sobre : fond blanc, contour fin, petits arrondis.
  Widget _box({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), double? width}) => Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: child,
      );

  /// Titre de section : texte net en gras, comme les grandes apps de service.
  Widget _title(String t, {VoidCallback? more}) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(t, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: _ar ? 0 : -0.2))),
          if (more != null)
            InkWell(
              onTap: more,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr('Voir tout', 'عرض الكل'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _link)),
                  const SizedBox(width: 2),
                  NIcon('chevron', size: 16, color: _link, accent: _link),
                ]),
              ),
            ),
        ]),
      );

  /// Mascotte-cloche : une image quand il y a des notifications non lues, une autre sinon.
  Widget _bell() {
    final has = store.unread > 0;
    return Semantics(
      button: true,
      label: tr('Notifications', 'الإشعارات'),
      child: Pressable(
        onTap: () => Navigator.push(context, smoothRoute(const NotificationsPage())),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Image.asset(has ? 'notif_new.png' : 'notif_none.png', key: ValueKey(has), width: 48, height: 48),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> lv) => Row(children: [
        Pressable(
          onTap: () => widget.goTo(4),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: lv['color'] as Color, width: 2)),
            child: NAvatar(id: store.avatarId, size: 44, color: avatarColors[store.avatarColor % avatarColors.length], initial: store.name.isEmpty ? '?' : store.name[0].toUpperCase()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting(), style: TextStyle(fontSize: 13, color: _muted)),
            Text(store.name.isEmpty ? '…' : store.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ]),
        ),
        _bell(),
      ]);

  /// Carte d'accès (encre noire) : solde de points + QR qui se renouvelle + code client.
  Widget _qrCard() => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        decoration: BoxDecoration(color: brandDark, borderRadius: BorderRadius.circular(20), border: _dark ? Border.all(color: Colors.white12) : null),
        child: ValueListenableBuilder<String>(
          valueListenable: tokenN,
          builder: (_, token, __) => Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_caps(tr('Mes points', 'نقاطي')), style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: _ls)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Image.asset('coin.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    AnimatedCount(store.total, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${tr('pts', 'نقطة')} · ${store.wallet.length} ${tr('commerce(s)', 'متجر')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54))),
                  ]),
                ]),
              ),
              IconButton(icon: const NIcon('refresh', color: Colors.white70, accent: brandYellow), tooltip: tr('Renouveler', 'تجديد'), onPressed: _restart),
            ]),
            const SizedBox(height: 8),
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
                    builder: (_, v, __) => CustomPaint(size: const Size(252, 252), painter: _RingPainter(token.isEmpty ? 0 : v, track: Colors.white12, arc: brandYellow)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c)),
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
            const SizedBox(height: 6),
            Text(tr('Touchez le QR pour l\'agrandir · renouvelé toutes les 45 s', 'المس الرمز لتكبيره · يتجدد كل 45 ثانية'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 14),
            const Padding(padding: EdgeInsetsDirectional.only(end: 8), child: Divider(height: 1, color: Colors.white12)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Pressable(
                onTap: () {
                  if (store.code.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: store.code));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Code copié', 'تم نسخ الرمز'))));
                },
                child: Column(children: [
                  Text(tr('Mon code client · à donner si le scan ne marche pas', 'رمز الزبون · أعطه إن لم ينجح المسح'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(store.code.isEmpty ? '······' : store.code, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 6, fontFamily: 'monospace')),
                    const SizedBox(width: 10),
                    const NIcon('copy', color: Colors.white54, size: 18),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      );

  Widget _bannerSkeleton() => LayoutBuilder(
        builder: (context, box) => SizedBox(
          height: _bannerH(box.maxWidth),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.92,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AspectRatio(aspectRatio: 2.1, child: Container(decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(16)))),
                  const SizedBox(height: 12),
                  Container(width: 150, height: 14, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(width: 220, height: 11, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(6))),
                ]),
              ),
            ),
          ),
        ),
      );

  /// Textes affichés par défaut sur les bannières (ordre cyclique) : (titre FR, sous-titre FR, titre AR, sous-titre AR).
  static const _bannerDefaults = [
    ('Gagnez des points à chaque visite', 'Présentez votre QR chez nos commerçants partenaires', 'اكسب نقاطًا في كل زيارة', 'اعرض رمزك عند التجار الشركاء'),
    ('Des récompenses près de chez vous', 'Échangez vos points contre des cadeaux et des réductions', 'مكافآت قريبة منك', 'استبدل نقاطك بهدايا وتخفيضات'),
    ('Découvrez les offres du moment', 'Profitez des promotions de vos commerces préférés', 'اكتشف عروض الوقت', 'استفد من عروض متاجرك المفضلة'),
    ('Invitez vos amis', 'Parrainez et gagnez des points ensemble', 'ادعُ أصدقاءك', 'أحِل أصدقاءك واكسبوا النقاط معًا'),
  ];

  /// Texte de la bannière i. Si le fichier s'appelle « 01__Titre__Sous-titre.jpg », on l'utilise
  /// (le « _ » simple devient un espace) ; sinon, texte par défaut ci-dessus.
  (String, String) _bannerText(int i) {
    final n = i < bannerNames.length ? bannerNames[i] : '';
    final base = n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
    final parts = base.split('__');
    if (parts.length >= 3) return (parts[1].replaceAll('_', ' ').trim(), parts[2].replaceAll('_', ' ').trim());
    final d = _bannerDefaults[i % _bannerDefaults.length];
    return (tr(d.$1, d.$3), tr(d.$2, d.$4));
  }

  /// Une diapo : l'image, puis le titre et le sous-titre juste en dessous (rien n'est écrit sur l'image).
  Widget _bannerSlide(int i) {
    final (title, sub) = _bannerText(i);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2.1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: _line,
              child: Image.network(
                banners[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, child: child),
                errorBuilder: (_, __, ___) => Container(alignment: Alignment.center, child: NIcon('tag', size: 36, color: _muted, accent: _gold)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
        ),
        if (sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
            child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: 13, height: 1.3)),
          ),
      ]),
    );
  }

  // hauteur réservée au texte sous l'image (titre 1 ligne + sous-titre 2 lignes)
  static const double _bannerTextH = 76;
  double _bannerH(double w) => (w * 0.92 - 8) / 2.1 + _bannerTextH; // image (ratio 2,1) + texte

  /// Carrousel de bannières (images du dossier Supabase), défilement automatique + points.
  Widget _bannerCarousel() => LayoutBuilder(builder: (context, box) => Column(children: [
        SizedBox(
          height: _bannerH(box.maxWidth),
          child: PageView.builder(
            controller: bannerPc,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => bannerIdx = i),
            itemBuilder: (_, i) => _bannerSlide(i),
          ),
        ),
        if (banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == bannerIdx ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == bannerIdx ? _ink : _ink.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]));

  /// Récompense disponible : carte sobre avec un filet jaune sur le côté.
  Widget _readyBanner(List<String> ready) => Pressable(
        onTap: () => widget.goTo(2),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: brandYellow),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    NIcon('gift', size: 28, color: _ink, accent: _gold),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Une récompense vous attend', 'مكافأة بانتظارك'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${ready.join(', ')} · ${tr('montrez votre code au commerçant', 'أظهر رمزك للتاجر')}', style: TextStyle(fontSize: 12, color: _muted)),
                      ]),
                    ),
                    NIcon('chevron', color: _muted, accent: _muted),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );

  /// Offres en cours : cartes sobres en défilement horizontal.
  Widget _offerCards(List<Map<String, dynamic>> deals) => SizedBox(
        height: 120,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final d in deals)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Pressable(
                onTap: () {
                  final s = store.shops.where((x) => x['id'] == d['shop_id']).toList();
                  if (s.isNotEmpty) _openShop(s.first);
                },
                child: _box(
                  width: 250,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      NIcon('tag', size: 16, color: _ink, accent: _gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${(d['shops'] as Map?)?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _muted))),
                    ]),
                    Text('${d['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.25)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  /// Favoris : logos ronds avec un contour fin.
  Widget _favsRow(List<Map<String, dynamic>> favs) {
    if (favs.isEmpty) {
      return _box(
        child: Row(children: [
          NIcon('star', size: 26, color: _ink, accent: _gold),
          const SizedBox(width: 14),
          Expanded(child: Text(tr('Touchez l’étoile sur la fiche d’un commerce pour le retrouver ici.', 'المس النجمة في صفحة المتجر لتجده هنا.'), style: TextStyle(color: _muted, fontSize: 13, height: 1.35))),
        ]),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final s in favs)
          Pressable(
            onTap: () => _openShop(s),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Column(children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _line, width: 1.5)),
                  child: ClipOval(child: ShopLogo(shop: s, size: 54)),
                ),
                const SizedBox(height: 6),
                SizedBox(width: 68, child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
          ),
      ]),
    );
  }

  /// Niveau fidélité : carte sobre avec barre de progression fine.
  Widget _levelCard(Map<String, dynamic> lv, int? next, double progress) {
    final c = lv['color'] as Color;
    return Pressable(
      onTap: () => widget.goTo(4),
      child: _box(
        child: Row(children: [
          NIcon('trophy', size: 30, color: c),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('Membre', 'عضو')} ${lv['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 4, color: c, backgroundColor: _ink.withOpacity(0.10))),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? tr('Niveau maximum atteint', 'وصلت لأعلى مستوى') : '${next - (lv['visits'] as int)} ${tr('visites avant le prochain niveau', 'زيارة للمستوى التالي')}',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          NIcon('chevron', color: _muted, accent: _muted),
        ]),
      ),
    );
  }

  /// Ligne d'activité : liste simple, séparée par des filets.
  Widget _activityTile(Map<String, dynamic> a) {
    final reward = a['type'] == 'reward';
    final amount = a['amount'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _line, width: 1.5)),
          child: NIcon(reward ? 'gift' : 'add', size: 20, color: _ink, accent: _gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['shop'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text(fmtDate(a['at'] as String?), style: TextStyle(fontSize: 12, color: _muted)),
          ]),
        ),
        Text('${amount > 0 ? '+' : ''}$amount', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
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
          return RefreshIndicator(
            color: _ink,
            backgroundColor: _card,
            onRefresh: () async { await store.refresh(); await _loadBanners(); },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              FadeSlideIn(child: _header(lv)),
              const SizedBox(height: 18),
              FadeSlideIn(index: 1, child: _qrCard()),
              if (bannersLoading || banners.isNotEmpty) ...[
                const SizedBox(height: 22),
                banners.isEmpty ? _bannerSkeleton() : FadeSlideIn(index: 2, child: _bannerCarousel()),
              ],
              if (ready.isNotEmpty) ...[
                const SizedBox(height: 18),
                FadeSlideIn(index: 3, child: _readyBanner(ready)),
              ],
              if (deals.isNotEmpty) ...[
                _title(tr('Offres en cours', 'العروض الحالية'), more: () => widget.goTo(3)),
                _offerCards(deals),
              ],
              _title(tr('Mes favoris', 'مفضلتي')),
              _favsRow(favs),
              _title(tr('Fidélité', 'الولاء')),
              _levelCard(lv, next, progress),
              _title(tr('Activité récente', 'النشاط الأخير'), more: () => Navigator.push(context, smoothRoute(const HistoryPage()))),
              if (acts.isEmpty)
                _box(
                  child: Row(children: [
                    NIcon('history', size: 26, color: _ink, accent: _gold),
                    const SizedBox(width: 14),
                    Expanded(child: Text(tr('Aucune visite pour le moment. Montrez votre QR chez un commerçant partenaire !', 'لا زيارات بعد. اعرض رمزك عند تاجر شريك!'), style: TextStyle(color: _muted, fontSize: 13, height: 1.35))),
                  ]),
                ),
              for (var i = 0; i < acts.length; i++) ...[
                if (i > 0) Divider(height: 1, color: _line),
                _activityTile(acts[i]),
              ],
            ]),
          );
        },
      );
}
