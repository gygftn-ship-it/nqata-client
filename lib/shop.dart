import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
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
class ShopPage extends StatelessWidget {
  final Map<String, dynamic> shop;
  final double? km;
  const ShopPage({super.key, required this.shop, this.km});

  void _share(BuildContext context, Map<String, dynamic> s) {
    final lat = (s['lat'] as num?)?.toDouble(), lng = (s['lng'] as num?)?.toDouble();
    final desc = '${s['description'] ?? ''}';
    final link = lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : '';
    final text = '${s['name']}${desc.isEmpty ? '' : '\n$desc'}\n📍 ${s['address'] ?? ''}${link.isEmpty ? '' : '\n$link'}\n${tr('Découvrez-le sur Nqata', 'اكتشفه على نقطة')}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Lien copié : collez-le dans WhatsApp ou un message', 'تم نسخ الرابط: الصقه في واتساب أو رسالة'))));
  }

  Widget _circleBtn(String i, VoidCallback onTap, {Color color = Colors.white}) =>
      Padding(padding: const EdgeInsets.only(left: 6), child: CircleAvatar(backgroundColor: Colors.black45, child: IconButton(icon: NIcon(i, color: color), onPressed: onTap)));

  Widget _chip(String text, {Color? bg, Color fg = Colors.black87, String? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg ?? Colors.black12, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[NIcon(icon, size: 15, color: fg), const SizedBox(width: 5)], Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600))]),
      );

  Widget _row(String i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [NIcon(i, size: 20, color: brandLight), const SizedBox(width: 10), Expanded(child: Text(t))]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final s = store.shops.firstWhere((x) => x['id'] == shop['id'], orElse: () => shop);
          final id = '${s['id']}';
          final theme = Theme.of(context);
          final fav = store.favs.contains(id);
          final open = openNow(s['hours'] as String?);
          final rating = store.ratings[id];
          final my = store.myRatings[id] ?? 0;
          final rows = store.wallet.where((r) => (r['shops'] as Map?)?['id'] == s['id']).toList();
          final visited = rows.isNotEmpty;
          final pts = visited ? rows.first['points'] as int : 0;
          final thr = (s['reward_threshold'] as int?) ?? 100;
          final offers = store.offers.where((o) => o['shop_id'] == s['id']).toList();
          final lat = (s['lat'] as num?)?.toDouble(), lng = (s['lng'] as num?)?.toDouble();
          final desc = '${s['description'] ?? ''}'.trim();
          final top = MediaQuery.of(context).padding.top;
          return Scaffold(
            body: ListView(padding: EdgeInsets.zero, children: [
              Stack(clipBehavior: Clip.none, children: [
                ShopCover(shop: s, height: 190 + top),
                Positioned(top: top + 6, left: 8, child: _circleBtn('back', () => Navigator.pop(context))),
                Positioned(
                  top: top + 6,
                  right: 8,
                  child: Row(children: [
                    _circleBtn(fav ? 'star_fill' : 'star', () => store.toggleFav(id), color: Colors.amber),
                    _circleBtn('share', () => _share(context, s)),
                  ]),
                ),
                PositionedDirectional(bottom: -42, start: 20, child: ShopLogo(shop: s, size: 88)),
              ]),
              const SizedBox(height: 52),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _chip(rating == null ? tr('Nouveau', 'جديد') : '${(rating['avg_rating'] as num).toStringAsFixed(1)} (${rating['reviews_count']})', icon: 'star_fill', bg: Colors.amber.shade100),
                    _chip(catLabel(s['category'] as String?), icon: catIcon(s['category'] as String?)),
                    if (open != null) _chip(open ? tr('Ouvert', 'مفتوح') : tr('Fermé', 'مغلق'), bg: open ? Colors.green.shade100 : Colors.red.shade100),
                  ]),
                  if (desc.isNotEmpty) ...[const SizedBox(height: 14), Text(desc, style: theme.textTheme.bodyLarge)],
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        _row('history', '${s['hours'] ?? tr('Horaires non renseignés', 'ساعات العمل غير محددة')}'),
                        _row('pin', '${s['address'] ?? ''}'),
                        if ((km ?? store.km(s)) != null) _row('near', '${(km ?? store.km(s))!.toStringAsFixed(1)} km'),
                      ]),
                    ),
                  ),
                  if (lat != null && lng != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 150,
                        child: FlutterMap(
                          options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dz.nqata.client'),
                            MarkerLayer(markers: [Marker(point: LatLng(lat, lng), width: 44, height: 44, child: const NIcon('pin', color: brandDark, size: 44))]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const NIcon('directions'),
                      label: Text(tr('Itinéraire', 'الاتجاهات')),
                      onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    index: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [brandDark, brandLight])),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Mes points ici', 'نقاطي هنا'), style: const TextStyle(color: Colors.white70)),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          AnimatedCount(pts, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                          Padding(padding: const EdgeInsets.only(bottom: 6, left: 6), child: Text('/ $thr', style: const TextStyle(color: Colors.white70))),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (pts % thr) / thr, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(pts >= thr ? tr('Récompense disponible !', 'مكافأة متاحة!') : tr('Encore ${thr - pts % thr} points avant une récompense', 'بقي ${thr - pts % thr} نقطة للمكافأة'), style: const TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(tr('Offres sur Nqata', 'العروض على نقطة'), style: theme.textTheme.titleMedium),
                  if (offers.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Aucune offre pour le moment', 'لا توجد عروض حاليًا'))),
                  for (var i = 0; i < offers.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: cardGrads[(i + 1) % 4])),
                        child: Row(children: [
                          const NIcon('tag', color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${offers[i]['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(tr('Votre note', 'تقييمك'), style: theme.textTheme.titleMedium),
                  Row(children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: visited
                            ? () async {
                                try {
                                  await store.rate(id, i);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Merci pour votre note !', 'شكرًا على تقييمك!'))));
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
                                }
                              }
                            : null,
                        icon: NIcon(i <= my ? 'star_fill' : 'star', color: Colors.amber, size: 36),
                      ),
                  ]),
                  if (!visited) Text(tr('Visitez ce commerce pour pouvoir le noter.', 'زر هذا المتجر لتتمكن من تقييمه.'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 18),
                  FilledButton.icon(icon: const NIcon('share'), label: Text(tr('Copier le lien de partage', 'نسخ رابط المشاركة')), onPressed: () => _share(context, s)),
                  const SizedBox(height: 32),
                ]),
              ),
            ]),
          );
        },
      );
}
