import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nicons.dart';
import 'main.dart';
import 'home.dart'; // Pressable
import 'profile.dart'; // coverThemes (même en-tête que le profil)
import 'shop.dart';
import 'tabs.dart';

/// Onglet « Offres » : même charte que le Profil (en-tête sombre dégradé, feuille aux coins
/// arrondis, cartes teintées sans ombre, accents or/jaune), avec la structure du modèle :
/// recherche, catégories, filtres, puis liste de commerces (image à gauche, infos à droite).
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

  // ---------- Style commun (mêmes valeurs que profile.dart) ----------
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => _ink.withOpacity(0.62);
  Color get _gold => _dark ? brandYellow : brandLight; // accent des icônes
  Color get _link => _dark ? brandYellow : const Color(0xFF8A6500); // texte or lisible sur fond clair
  Color get _tint => _dark ? const Color(0xFF1B1912) : const Color(0xFFF6F3EA); // fond des cartes et tuiles
  (String, String, Color, Color) get _cover => coverThemes[store.coverTheme % coverThemes.length];

  // ---------- Données ----------
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

  // Horaires « 08:00–20:00 » : heure d'ouverture (g = 1) ou de fermeture (g = 3)
  String? _hour(String? hours, int g) {
    if (hours == null) return null;
    final m = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})\s*[–—-]\s*(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(hours);
    if (m == null) return null;
    return '${m[g]!.padLeft(2, '0')}:${m[g + 1]}';
  }

  /// « Ouvre à 08:00 » / « Ouvert jusqu'à 20:00 » (équivalent du « Disponible à … » du modèle)
  String _avail(Map<String, dynamic> s) {
    final h = s['hours'] as String?;
    final open = openNow(h);
    if (open == null) return h ?? '';
    return open ? tr('Ouvert jusqu\'à ${_hour(h, 3)}', 'مفتوح حتى ${_hour(h, 3)}') : tr('Ouvre à ${_hour(h, 1)}', 'يفتح عند ${_hour(h, 1)}');
  }

  String get _sortLabel => switch (sort) {
        'near' => tr('Plus proches', 'الأقرب'),
        'rating' => tr('Mieux notés', 'الأعلى تقييمًا'),
        'name' => tr('Nom (A-Z)', 'الاسم'),
        _ => tr('Trier', 'ترتيب'),
      };

  // ---------- En-tête sombre (comme le Profil) ----------
  Widget _glassButton({required String icon, String? label, required String semantics, required VoidCallback onTap, bool active = false}) => Semantics(
        button: true,
        label: semantics,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            constraints: const BoxConstraints(minWidth: 44),
            padding: EdgeInsetsDirectional.symmetric(horizontal: label == null ? 0 : 14),
            decoration: BoxDecoration(
              color: active ? brandYellow : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: active ? brandYellow : Colors.white30),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              NIcon(icon, size: 20, color: active ? Colors.black87 : Colors.white, accent: active ? Colors.black87 : brandYellow),
              if (label != null) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.black87 : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600))),
              ],
            ]),
          ),
        ),
      );

  Widget _header(double top) {
    final cv = _cover;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 20),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cv.$3, cv.$4])),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(tr('Offres', 'العروض'), style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : -0.4))),
          Flexible(
            child: _glassButton(
              icon: 'locate',
              label: store.me != null ? tr('Autour de moi', 'حولي') : tr('Ma position', 'موقعي'),
              semantics: tr('Utiliser ma position', 'استخدم موقعي'),
              onTap: () => store.locate(ask: true),
            ),
          ),
          const SizedBox(width: 10),
          _glassButton(
            icon: 'star_fill',
            semantics: tr('Mes favoris', 'مفضلتي'),
            active: favOnly,
            onTap: () { HapticFeedback.selectionClick(); setState(() => favOnly = !favOnly); },
          ),
        ]),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => query = v),
          cursorColor: brandYellow,
          style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.10),
            hintText: tr('Rechercher un commerce', 'ابحث عن محل'),
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: NIcon('search', size: 22, color: Colors.white, accent: brandYellow)),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: brandYellow, width: 1.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
          ),
        ),
        if (store.offers.isNotEmpty) ...[const SizedBox(height: 16), _banner()],
      ]),
    );
  }

  /// Carte jaune (même gabarit que la bannière de niveau du Profil) : offres en cours.
  Widget _banner() {
    final count = store.offers.length;
    final shops = store.offers.map((o) => o['shop_id']).toSet().length;
    return Pressable(
      onTap: () { HapticFeedback.selectionClick(); setState(() => cat = 'promo'); },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Offres en cours', 'عروض جارية'), style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('Chez $shops commerce(s) partenaire(s)', 'لدى $shops متجر شريك'), style: const TextStyle(color: Colors.black87, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 18),
          Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedCount(count, style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(width: 8),
            const NIcon('chevron', size: 18, color: Colors.black87, accent: Colors.black87),
          ]),
        ]),
      ),
    );
  }

  // ---------- Feuille claire ----------
  Widget _title(String t) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 20, end: 20, top: 24, bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: lang == 'ar' ? 0 : -0.2)),
      );

  Widget _catItem((String, String, String, String) c) {
    final sel = cat == c.$1;
    return Semantics(
      button: true,
      selected: sel,
      label: tr(c.$3, c.$4),
      child: Pressable(
        onTap: () { HapticFeedback.selectionClick(); setState(() => cat = sel ? 'all' : c.$1); },
        child: SizedBox(
          width: 80,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: sel ? brandYellow : _tint, borderRadius: BorderRadius.circular(18)),
              child: NIcon(c.$2, size: 28, color: sel ? Colors.black87 : _ink, accent: sel ? Colors.white : _gold),
            ),
            const SizedBox(height: 8),
            Text(tr(c.$3, c.$4), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  /// Pastille de filtre : fond teinté, jaune quand elle est active.
  Widget _chip(String label, {String? icon, bool selected = false, bool arrow = false}) {
    final fg = selected ? Colors.black87 : _ink;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: selected ? brandYellow : _tint, borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[NIcon(icon, size: 18, color: fg, accent: selected ? Colors.white : _gold), const SizedBox(width: 7)],
        Text(label, style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, fontSize: 14)),
        if (arrow) ...[const SizedBox(width: 4), NIcon('drop', size: 18, color: fg, accent: fg)],
      ]),
    );
  }

  Widget _dealCard(Map<String, dynamic> d, int i) => Pressable(
        onTap: () {
          final s = store.shops.where((x) => x['id'] == d['shop_id']).toList();
          if (s.isNotEmpty) _open(s.first);
        },
        child: Container(
          width: 240,
          margin: const EdgeInsetsDirectional.only(end: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cardGrads[i % 4])),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${d['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${(d['shops'] as Map?)?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 10),
            const NIcon('tag', size: 26, color: Colors.white, accent: brandYellow),
          ]),
        ),
      );

  /// Carte d'un commerce : image à gauche (cadenas « Fermé »), infos à droite.
  Widget _shopCard(Map<String, dynamic> s, int i) {
    final closed = openNow(s['hours'] as String?) == false;
    final n = _offers(s);
    final r = store.ratings['${s['id']}'];
    final km = store.km(s);
    final id = '${s['id']}';
    final fav = store.favs.contains(id);
    final info = '${_avail(s)}${km == null ? '' : ' • ${km.toStringAsFixed(1)} km'}';
    return FadeSlideIn(
      index: i,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Pressable(
          onTap: () => _open(s),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(22)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 112,
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: closed ? 0.5 : 1,
                        child: Stack(alignment: Alignment.center, children: [Positioned.fill(child: ShopCover(shop: s, height: 100)), ShopLogo(shop: s, size: 54)]),
                      ),
                    ),
                    if (closed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(color: brandDark.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const NIcon('lock', size: 14, color: Colors.white, accent: brandYellow),
                          const SizedBox(width: 5),
                          Text(tr('Fermé', 'مغلق'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2))),
                    Semantics(
                      button: true,
                      label: tr('Favori', 'مفضل'),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () { HapticFeedback.selectionClick(); store.toggleFav(id); },
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8, end: 2, bottom: 4),
                          child: fav ? const NIcon('star_fill', size: 20, color: Colors.amber, accent: Colors.amber) : NIcon('star', size: 20, color: _ink.withOpacity(0.4)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: _ink.withOpacity(_dark ? 0.12 : 0.07), borderRadius: BorderRadius.circular(10)),
                      child: r == null
                          ? Text(tr('Nouveau', 'جديد'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const NIcon('star_fill', size: 13, color: Colors.amber, accent: Colors.amber),
                              const SizedBox(width: 3),
                              Text((r['avg_rating'] as num).toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ]),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Text('• ${catLabel(s['category'] as String?)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: 13))),
                  ]),
                  const SizedBox(height: 8),
                  Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _muted)),
                  if (n > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: brandYellow.withOpacity(_dark ? 0.16 : 0.28), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        NIcon('tag', size: 14, color: _link, accent: _link),
                        const SizedBox(width: 5),
                        Text(tr('$n offre(s)', '$n عرض'), style: TextStyle(color: _link, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // icônes de la barre d'état claires sur l'en-tête sombre
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final list = _filtered();
            final deals = store.offers.take(8).toList();
            final top = MediaQuery.of(context).padding.top;
            const rowPad = EdgeInsetsDirectional.symmetric(horizontal: 16);
            return RefreshIndicator(
              onRefresh: store.refresh,
              edgeOffset: top,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [
                FadeSlideIn(child: _header(top)),
                // le fond sombre n'apparaît que derrière les coins arrondis de la feuille
                Container(
                  color: _cover.$4,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 22, bottom: 28),
                    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FadeSlideIn(index: 1, child: SizedBox(height: 92, child: ListView(padding: rowPad, scrollDirection: Axis.horizontal, children: [for (final c in cats) _catItem(c)]))),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 2,
                        child: SizedBox(
                          height: 42,
                          child: ListView(padding: rowPad, scrollDirection: Axis.horizontal, children: [
                            PopupMenuButton<String>(
                              onSelected: (v) { setState(() => sort = v); if (v == 'near') store.locate(ask: true); },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'relevance', child: Text(tr('Pertinence', 'الأهمية'))),
                                PopupMenuItem(value: 'near', child: Text(tr('Plus proches', 'الأقرب'))),
                                PopupMenuItem(value: 'rating', child: Text(tr('Mieux notés', 'الأعلى تقييمًا'))),
                                PopupMenuItem(value: 'name', child: Text(tr('Nom (A-Z)', 'الاسم'))),
                              ],
                              child: _chip(_sortLabel, icon: 'list', selected: sort != 'relevance', arrow: true),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () { HapticFeedback.selectionClick(); setState(() => openOnly = !openOnly); },
                              child: _chip(tr('Ouvert maintenant', 'مفتوح الآن'), icon: 'bolt', selected: openOnly),
                            ),
                          ]),
                        ),
                      ),
                      if (deals.isNotEmpty) ...[
                        _title(tr('Offres du moment', 'عروض الساعة')),
                        SizedBox(height: 88, child: ListView(padding: rowPad, scrollDirection: Axis.horizontal, children: [for (var i = 0; i < deals.length; i++) _dealCard(deals[i], i)])),
                      ],
                      _title(tr('Commerces', 'المحلات')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(children: [
                          if (list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(children: [
                                NIcon('store', size: 44, color: _ink.withOpacity(0.35), accent: _gold),
                                const SizedBox(height: 12),
                                Text(tr('Aucun commerce ne correspond', 'لا توجد محلات مطابقة'), textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                              ]),
                            ),
                          for (var i = 0; i < list.length; i++) _shopCard(list[i], i),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      );
}
