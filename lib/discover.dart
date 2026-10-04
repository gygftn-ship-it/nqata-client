import 'package:flutter/material.dart';
import 'nicons.dart';
import 'main.dart';
import 'shop.dart';
import 'tabs.dart';

/// Onglet « Offres et bons plans » : catégories, filtres, offres du moment, grille des commerces.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  String cat = 'all', sort = 'relevance', query = '';
  bool openOnly = false, favOnly = false;

  @override
  void initState() {
    super.initState();
    store.locate(); // sans demande : n'agit que si la localisation est déjà autorisée
  }

  static const cats = [
    ('promo', 'tag', 'Promos', 'عروض'),
    ('cafe', 'cafe', 'Café', 'مقهى'),
    ('food', 'basket', 'Alimentation', 'مواد غذائية'),
    ('health', 'medical', 'Santé', 'صحة'),
    ('beauty', 'scissors', 'Beauté', 'تجميل'),
    ('other', 'store', 'Autres', 'أخرى'),
  ];

  int _offers(Map<String, dynamic> s) => store.offers.where((o) => o['shop_id'] == s['id']).length;
  double _avg(Map<String, dynamic> s) => ((store.ratings['${s['id']}']?['avg_rating']) as num?)?.toDouble() ?? 0;
  void _open(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s)));

  List<Map<String, dynamic>> _filtered() {
    final list = store.shops.where((s) {
      if (query.isNotEmpty && !'${s['name']}'.toLowerCase().contains(query.toLowerCase())) return false;
      if (cat == 'promo' && _offers(s) == 0) return false;
      if (cat != 'all' && cat != 'promo' && s['category'] != cat) return false;
      if (openOnly && openNow(s['hours'] as String?) != true) return false;
      if (favOnly && !store.favs.contains('${s['id']}')) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      if (sort == 'near') {
        final ka = store.km(a), kb = store.km(b);
        if (ka == null && kb == null) return 0;
        if (ka == null) return 1;
        if (kb == null) return -1;
        return ka.compareTo(kb);
      }
      if (sort == 'rating') return _avg(b).compareTo(_avg(a));
      if (sort == 'name') return '${a['name']}'.compareTo('${b['name']}');
      final fa = store.favs.contains('${a['id']}') ? 1 : 0, fb = store.favs.contains('${b['id']}') ? 1 : 0;
      if (fa != fb) return fb - fa;
      final oa = _offers(a), ob = _offers(b);
      return oa != ob ? ob - oa : '${a['name']}'.compareTo('${b['name']}');
    });
    return list;
  }

  Widget _catItem((String, String, String, String) c) {
    final sel = cat == c.$1;
    return GestureDetector(
      onTap: () => setState(() => cat = sel ? 'all' : c.$1),
      child: Container(
        width: 78,
        color: Colors.transparent,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? brandLight.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: sel ? brandLight : Colors.transparent, width: 2),
            ),
            child: NIcon(c.$2, size: 32, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(tr(c.$3, c.$4), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s, int i) {
    final closed = openNow(s['hours'] as String?) == false;
    final n = _offers(s);
    final r = store.ratings['${s['id']}'];
    return FadeSlideIn(
      index: i,
      child: GestureDetector(
        onTap: () => _open(s),
        child: Opacity(
          opacity: closed ? 0.65 : 1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(alignment: Alignment.center, children: [
              ClipRRect(borderRadius: BorderRadius.circular(18), child: ShopCover(shop: s, height: 108)),
              ShopLogo(shop: s, size: 60),
              if (closed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF14213D), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const NIcon('lock', size: 14, color: Colors.white), const SizedBox(width: 4), Text(tr('Fermé', 'مغلق'), style: const TextStyle(color: Colors.white, fontSize: 12))]),
                ),
              if (n > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const NIcon('tag', size: 13, color: Colors.black87, accent: Colors.white), const SizedBox(width: 3), Text('$n', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold))]),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
              const NIcon('star_fill', size: 15, color: Colors.amber),
              const SizedBox(width: 2),
              Text(r == null ? tr('Nouveau', 'جديد') : (r['avg_rating'] as num).toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ]),
            Text(
              '${catLabel(s['category'] as String?)} · ${n > 0 ? tr('$n offre(s)', '$n عرض') : '${s['hours'] ?? ''}'}${store.km(s) == null ? '' : ' · ${store.km(s)!.toStringAsFixed(1)} km'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final list = _filtered();
          final deals = store.offers.take(8).toList();
          final theme = Theme.of(context);
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              Text(tr('Offres et bons plans', 'عروض وتخفيضات'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(prefixIcon: const NIcon('search'), hintText: tr('Rechercher un commerce', 'ابحث عن محل'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in cats) _catItem(c)])),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  PopupMenuButton<String>(
                    onSelected: (v) { setState(() => sort = v); if (v == 'near') store.locate(ask: true); },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'relevance', child: Text(tr('Pertinence', 'الأهمية'))),
                      PopupMenuItem(value: 'near', child: Text(tr('Plus proches', 'الأقرب'))),
                      PopupMenuItem(value: 'rating', child: Text(tr('Mieux notés', 'الأعلى تقييمًا'))),
                      PopupMenuItem(value: 'name', child: Text(tr('Nom (A-Z)', 'الاسم'))),
                    ],
                    child: Chip(label: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Trier', 'ترتيب')), const NIcon('drop')])),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(label: Text(tr('Ouvert maintenant', 'مفتوح الآن')), selected: openOnly, onSelected: (v) => setState(() => openOnly = v)),
                  const SizedBox(width: 8),
                  FilterChip(label: Row(mainAxisSize: MainAxisSize.min, children: [const NIcon('star_fill', size: 16, color: Colors.black87), const SizedBox(width: 4), Text(tr('Favoris', 'المفضلة'))]), selected: favOnly, onSelected: (v) => setState(() => favOnly = v)),
                ]),
              ),
              if (deals.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(tr('Offres du moment', 'عروض الساعة'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (var i = 0; i < deals.length; i++)
                      GestureDetector(
                        onTap: () {
                          final s = store.shops.where((x) => x['id'] == deals[i]['shop_id']).toList();
                          if (s.isNotEmpty) _open(s.first);
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
              const SizedBox(height: 18),
              Text(tr('Tous les commerces', 'كل المحلات'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun commerce ne correspond', 'لا توجد محلات مطابقة')))),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (var i = 0; i < list.length; i++) _card(list[i], i)],
              ),
            ]),
          );
        },
      );
}
