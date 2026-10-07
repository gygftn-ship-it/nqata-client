import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'main.dart';
import 'home.dart'; // Pressable
import 'map.dart'; // nqataTiles, mapAttribution
import 'tabs.dart';

// ---------- Catégories ----------
const catInfo = {
  'cafe': ('cafe', 'Café', 'مقهى'),
  'food': ('basket', 'Alimentation', 'مواد غذائية'),
  'health': ('medical', 'Santé', 'صحة'),
  'beauty': ('scissors', 'Beauté', 'تجميل'),
  'other': ('store', 'Autres', 'أخرى'),
};

String catLabel(String? c) {
  final i = catInfo[c] ?? catInfo['other']!;
  return tr(i.$2, i.$3);
}

String catIcon(String? c) => switch (c) {
      'cafe' => 'cafe',
      'food' => 'basket',
      'health' => 'medical',
      'beauty' => 'scissors',
      _ => 'store',
    };

/// Ouvert maintenant ? (null si les horaires ne sont pas au format 08:00–20:00)
bool? openNow(String? hours) {
  if (hours == null) return null;
  final m = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})\s*[–—-]\s*(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(hours);
  if (m == null) return null;
  final now = DateTime.now();
  final cur = now.hour * 60 + now.minute;
  final a = int.parse(m[1]!) * 60 + int.parse(m[2]!), b = int.parse(m[3]!) * 60 + int.parse(m[4]!);
  return a <= b ? (cur >= a && cur < b) : (cur >= a || cur < b);
}

Color? hexColor(String? h) {
  if (h == null || h.isEmpty) return null;
  try {
    return Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

/// Fond personnalisé du commerce : image envoyée par le commerçant, sinon sa couleur.
class ShopCover extends StatelessWidget {
  final Map<String, dynamic> shop;
  final double height;
  const ShopCover({super.key, required this.shop, required this.height});

  @override
  Widget build(BuildContext context) {
    final base = hexColor(shop['cover_color'] as String?) ?? brandYellow;
    final grad = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base, Color.lerp(base, Colors.white, 0.35)!])),
    );
    final url = shop['cover_url'] as String?;
    if (url == null || url.isEmpty) return grad;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => grad, loadingBuilder: (c, child, p) => p == null ? child : grad),
    );
  }
}

/// Logo rond du commerce (image du commerçant, sinon l'icône de sa catégorie).
class ShopLogo extends StatelessWidget {
  final Map<String, dynamic> shop;
  final double size;
  const ShopLogo({super.key, required this.shop, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = shop['logo_url'] as String?;
    final fallback = Center(child: NIcon(catIcon(shop['category'] as String?), size: size * 0.5, color: const Color(0xFF15120B)));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
      child: ClipOval(child: url == null || url.isEmpty ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)),
    );
  }
}

/// Fenêtre d'un commerce : fond, logo, note, description, horaires, localisation, offres, partage.
class ShopPage extends StatefulWidget {
  final Map<String, dynamic> shop;
  final double? km;
  const ShopPage({super.key, required this.shop, this.km});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int myStars = 0;
  late Future<List<Map<String, dynamic>>> reviews = store.shopReviews('${widget.shop['id']}');
  final comment = TextEditingController();

  // ---------- Style commun (mêmes valeurs que profile.dart) ----------
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => _ink.withOpacity(0.62);
  Color get _gold => _dark ? brandYellow : brandLight;
  Color get _link => _dark ? brandYellow : const Color(0xFF8A6500);
  Color get _tint => _dark ? const Color(0xFF1B1912) : const Color(0xFFF6F3EA);

  void _share(BuildContext context, Map<String, dynamic> s) {
    final lat = (s['lat'] as num?)?.toDouble(), lng = (s['lng'] as num?)?.toDouble();
    final desc = '${s['description'] ?? ''}';
    final link = lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : '';
    final text = '${s['name']}${desc.isEmpty ? '' : '\n$desc'}\n📍 ${s['address'] ?? ''}${link.isEmpty ? '' : '\n$link'}\n${tr('Découvrez-le sur Nqata', 'اكتشفه على نقطة')}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Lien copié : collez-le dans WhatsApp ou un message', 'تم نسخ الرابط: الصقه في واتساب أو رسالة'))));
  }

  /// Bouton rond sur l'image de couverture (fond sombre translucide : lisible sur toutes les couvertures).
  Widget _glass(String icon, String label, VoidCallback onTap, {bool amber = false}) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.35), border: Border.all(color: Colors.white30)),
            child: NIcon(icon, size: 22, color: amber ? Colors.amber : Colors.white, accent: amber ? Colors.amber : brandYellow),
          ),
        ),
      );

  Widget _chip(String text, {Color? bg, Color? fg, String? icon}) {
    final c = fg ?? _ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg ?? _ink.withOpacity(_dark ? 0.12 : 0.07), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[NIcon(icon, size: 15, color: c, accent: c), const SizedBox(width: 5)],
        Text(text, style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoRow(String icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NIcon(icon, size: 22, color: _ink, accent: _gold),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3))),
        ]),
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10, left: 4, right: 4),
        child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: lang == 'ar' ? 0 : -0.2)),
      );

  @override
  void initState() { super.initState(); myStars = store.myRatings['${widget.shop['id']}'] ?? 0; }

  @override
  void dispose() { comment.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final s = store.shops.firstWhere((x) => x['id'] == widget.shop['id'], orElse: () => widget.shop);
          final id = '${s['id']}';
          final fav = store.favs.contains(id);
          final open = openNow(s['hours'] as String?);
          final rating = store.ratings[id];
          final rows = store.wallet.where((r) => (r['shops'] as Map?)?['id'] == s['id']).toList();
          final visited = rows.isNotEmpty;
          final pts = visited ? rows.first['points'] as int : 0;
          final thr = (s['reward_threshold'] as int?) ?? 100;
          final offers = store.offers.where((o) => o['shop_id'] == s['id']).toList();
          final lat = (s['lat'] as num?)?.toDouble(), lng = (s['lng'] as num?)?.toDouble();
          final desc = '${s['description'] ?? ''}'.trim();
          final km = widget.km ?? store.km(s);
          final top = MediaQuery.of(context).padding.top;
          final bottom = MediaQuery.of(context).padding.bottom;
          final coverH = 220.0 + top;
          final okColor = _dark ? Colors.green.shade300 : Colors.green.shade800;
          final noColor = _dark ? Colors.red.shade300 : Colors.red.shade800;
          return Scaffold(
            body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light, // icônes de la barre d'état claires sur la couverture
              child: ListView(padding: EdgeInsets.zero, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Positioned(top: 0, left: 0, right: 0, height: coverH, child: ShopCover(shop: s, height: coverH)),
                  // voile sombre en haut : garde les boutons lisibles sur n'importe quelle image
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: top + 90,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.45), Colors.transparent]))),
                  ),
                  // feuille aux coins arrondis, comme le Profil
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(height: coverH - 28),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 54, 16, 0),
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s['name']}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: lang == 'ar' ? 0 : -0.4)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _chip(rating == null ? tr('Nouveau', 'جديد') : '${(rating['avg_rating'] as num).toStringAsFixed(1)} (${rating['reviews_count']})', icon: 'star_fill', bg: Colors.amber.withOpacity(_dark ? 0.2 : 0.22), fg: _dark ? Colors.amber.shade200 : const Color(0xFF7A5A00)),
                              _chip(catLabel(s['category'] as String?), icon: catIcon(s['category'] as String?)),
                              if (open != null) _chip(open ? tr('Ouvert', 'مفتوح') : tr('Fermé', 'مغلق'), bg: (open ? Colors.green : Colors.red).withOpacity(_dark ? 0.2 : 0.14), fg: open ? okColor : noColor),
                            ]),
                            if (desc.isNotEmpty) ...[const SizedBox(height: 16), Text(desc, style: TextStyle(fontSize: 15.5, height: 1.45, color: _ink.withOpacity(0.85)))],
                          ]),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(22)),
                            child: Column(children: [
                              _infoRow('history', '${s['hours'] ?? tr('Horaires non renseignés', 'ساعات العمل غير محددة')}'),
                              if ('${s['address'] ?? ''}'.isNotEmpty) _infoRow('pin', '${s['address']}'),
                              if (km != null) _infoRow('near', '${km.toStringAsFixed(1)} km'),
                            ]),
                          ),
                        ),
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: SizedBox(
                              height: 170,
                              child: FlutterMap(
                                options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                                children: [
                                  nqataTiles(context),
                                  MarkerLayer(markers: [
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 52,
                                      height: 52,
                                      child: Center(
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: brandYellow, border: Border.all(color: brandDark, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]),
                                          child: NIcon(catIcon(s['category'] as String?), size: 21, color: brandDark, accent: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  mapAttribution,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const NIcon('directions', color: Colors.black87, accent: Colors.black87),
                              label: Text(tr('Itinéraire', 'الاتجاهات')),
                              onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        // carte jaune (même gabarit que la bannière de niveau du Profil)
                        FadeSlideIn(
                          index: 1,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(18)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(tr('Mes points ici', 'نقاطي هنا'), style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(pts >= thr ? tr('Récompense disponible !', 'مكافأة متاحة!') : tr('Encore ${thr - pts % thr} points avant une récompense', 'بقي ${thr - pts % thr} نقطة للمكافأة'), style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                  ]),
                                ),
                                const SizedBox(width: 18),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  AnimatedCount(pts, style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
                                  Text('/ $thr ${tr('points', 'نقطة')}', style: const TextStyle(color: Colors.black87, fontSize: 11.5)),
                                ]),
                              ]),
                              const SizedBox(height: 10),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: (pts % thr) / thr),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 6, color: Colors.black87, backgroundColor: Colors.black12)),
                              ),
                            ]),
                          ),
                        ),
                        _title(tr('Offres sur Nqata', 'العروض على نقطة')),
                        if (offers.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(18)),
                            child: Text(tr('Aucune offre pour le moment', 'لا توجد عروض حاليًا'), style: TextStyle(color: _muted)),
                          ),
                        for (var i = 0; i < offers.length; i++)
                          FadeSlideIn(
                            index: i,
                            child: Container(
                              margin: EdgeInsets.only(top: i == 0 ? 0 : 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cardGrads[(i + 1) % 4])),
                              child: Row(children: [
                                const NIcon('tag', size: 26, color: Colors.white, accent: brandYellow),
                                const SizedBox(width: 14),
                                Expanded(child: Text('${offers[i]['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                              ]),
                            ),
                          ),
                        _title(tr('Votre note', 'تقييمك')),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(22)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              for (var i = 1; i <= 5; i++)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: visited ? () { HapticFeedback.selectionClick(); setState(() => myStars = i); } : null,
                                  icon: NIcon(i <= myStars ? 'star_fill' : 'star', color: visited ? Colors.amber : _ink.withOpacity(0.3), accent: Colors.amber, size: 36),
                                ),
                            ]),
                            if (!visited) Center(child: Text(tr('Visitez ce commerce pour pouvoir le noter.', 'زر هذا المتجر لتتمكن من تقييمه.'), textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13.5))),
                            if (visited && myStars > 0) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: comment,
                                maxLength: 500,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: tr('Votre avis (optionnel)', 'رأيك (اختياري)'),
                                  filled: true,
                                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _gold, width: 1.5)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: FilledButton(
                                  onPressed: () async {
                                    try {
                                      await store.rate(id, myStars, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
                                      if (mounted) setState(() => reviews = store.shopReviews(id));
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Merci pour votre avis !', 'شكرًا على رأيك!'))));
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
                                    }
                                  },
                                  child: Text(tr('Publier', 'نشر')),
                                ),
                              ),
                            ],
                          ]),
                        ),
                        _title(tr('Avis des clients', 'آراء الزبائن')),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: reviews,
                          builder: (_, snap) {
                            final list = snap.data ?? const [];
                            if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
                            if (list.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(18)),
                                child: Text(tr('Aucun avis pour le moment', 'لا توجد آراء حاليًا'), style: TextStyle(color: _muted)),
                              );
                            }
                            return Column(children: [
                              for (final rv in list)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(18)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text('${rv['display_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                      for (var i = 1; i <= 5; i++) NIcon(i <= (rv['rating'] as int) ? 'star_fill' : 'star', size: 14, color: Colors.amber, accent: Colors.amber),
                                    ]),
                                    if ('${rv['comment'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 6), Text('${rv['comment']}', style: const TextStyle(fontSize: 14.5, height: 1.4))],
                                    if (rv['reply'] != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('${s['name']} : ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                          Expanded(child: Text('${rv['reply']}', style: const TextStyle(fontSize: 12.5, height: 1.35))),
                                        ]),
                                      ),
                                    ],
                                  ]),
                                ),
                            ]);
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(icon: NIcon('share', color: _link, accent: _link), label: Text(tr('Copier le lien de partage', 'نسخ رابط المشاركة')), onPressed: () => _share(context, s)),
                        ),
                        SizedBox(height: 32 + bottom),
                      ]),
                    ),
                  ]),
                  // logo à cheval sur la couverture et la feuille
                  PositionedDirectional(top: coverH - 28 - 44, start: 24, child: ShopLogo(shop: s, size: 88)),
                  PositionedDirectional(top: top + 8, start: 16, child: _glass('back', tr('Retour', 'رجوع'), () => Navigator.pop(context))),
                  PositionedDirectional(
                    top: top + 8,
                    end: 16,
                    child: Row(children: [
                      _glass(fav ? 'star_fill' : 'star', tr('Favori', 'مفضل'), () { HapticFeedback.selectionClick(); store.toggleFav(id); }, amber: true),
                      const SizedBox(width: 10),
                      _glass('share', tr('Partager', 'مشاركة'), () => _share(context, s)),
                    ]),
                  ),
                ]),
              ]),
            ),
          );
        },
      );
}
