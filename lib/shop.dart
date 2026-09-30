import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'tabs.dart';

IconData catIcon(String? c) => switch (c) {
      'cafe' => Icons.local_cafe_rounded,
      'food' => Icons.shopping_basket_rounded,
      'health' => Icons.medical_services_rounded,
      'beauty' => Icons.content_cut_rounded,
      _ => Icons.storefront_rounded,
    };

/// Fiche détaillée d'un commerce : infos, mes points, offres, favori, itinéraire.
class ShopPage extends StatelessWidget {
  final Map<String, dynamic> shop;
  final double? km;
  const ShopPage({super.key, required this.shop, this.km});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final id = '${shop['id']}';
          final fav = store.favs.contains(id);
          final rows = store.wallet.where((r) => (r['shops'] as Map?)?['id'] == shop['id']).toList();
          final pts = rows.isEmpty ? 0 : rows.first['points'] as int;
          final thr = (shop['reward_threshold'] as int?) ?? 100;
          final offers = store.offers.where((o) => (o['shops'] as Map?)?['name'] == shop['name']).toList();
          final lat = (shop['lat'] as num?)?.toDouble(), lng = (shop['lng'] as num?)?.toDouble();
          final theme = Theme.of(context);
          Widget info(IconData i, String t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [Icon(i, size: 20, color: brandLight), const SizedBox(width: 10), Expanded(child: Text(t))]),
              );
          return Scaffold(
            appBar: AppBar(
              title: Text('${shop['name']}'),
              actions: [IconButton(icon: Icon(fav ? Icons.star : Icons.star_border, color: Colors.amber), onPressed: () => store.toggleFav(id))],
            ),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: cardGrads[0])),
                  child: Row(children: [
                    Icon(catIcon(shop['category'] as String?), color: Colors.white, size: 44),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${shop['name']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${shop['address'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              info(Icons.schedule, '${shop['hours'] ?? '-'}'),
              if (km != null) info(Icons.near_me, '${km!.toStringAsFixed(1)} km'),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Mes points ici', 'نقاطي هنا'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      AnimatedCount(pts, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('/ $thr')),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (pts % thr) / thr, minHeight: 8)),
                    const SizedBox(height: 6),
                    Text(pts >= thr ? tr('🎁 Récompense disponible !', '🎁 مكافأة متاحة!') : tr('Encore ${thr - pts % thr} points avant une récompense', 'بقي ${thr - pts % thr} نقطة للمكافأة')),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text(tr('Offres en cours', 'العروض الحالية'), style: theme.textTheme.titleMedium),
              if (offers.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Aucune offre pour le moment', 'لا توجد عروض حاليًا'))),
              for (var i = 0; i < offers.length; i++)
                FadeSlideIn(
                  index: i,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: cardGrads[(i + 2) % 4])),
                    child: Row(children: [
                      const Icon(Icons.local_offer_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${offers[i]['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ]),
                  ),
                ),
              if (lat != null && lng != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.directions),
                  label: Text(tr('Itinéraire', 'الاتجاهات')),
                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication),
                ),
              ],
            ]),
          );
        },
      );
}
