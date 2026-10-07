import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nicons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'main.dart';
import 'home.dart'; // Pressable
import 'profile.dart'; // coverThemes (même en-tête que le Profil)
import 'shop.dart';
import 'tabs.dart';

// =====================================================================
//  Fond de carte
// =====================================================================
/// Fournisseur du fond de carte. Deux options, au choix (voir les notes ci-dessous) :
///
/// 1) MapTiler (recommandé pour un rendu 100 % à vos couleurs) : créez un compte sur maptiler.com,
///    collez votre clé dans [mapTilerKey]. Le plan gratuit est réservé à un usage non commercial ;
///    l'usage commercial demande un plan payant. Dans l'éditeur de styles MapTiler, vous pouvez
///    dupliquer un style et le teinter (jaune Nqata, encre chaude) : collez alors ses identifiants
///    dans [mapTilerStyleLight] et [mapTilerStyleDark].
/// 2) CARTO (par défaut tant que [mapTilerKey] est vide) : clé gratuite sur
///    https://www.carto.com/basemaps/apikey/ à coller dans [cartoKey]. Prévue pour un usage non
///    commercial ; au-delà, CARTO peut demander un accord commercial.
const mapTilerKey = '';
const mapTilerStyleLight = 'dataviz-light';
const mapTilerStyleDark = 'dataviz-dark';
const cartoKey = '';

/// Fond de carte sobre, clair ou sombre selon le thème : utilisé par la carte et par la fiche commerce.
TileLayer nqataTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final retina = RetinaMode.isHighDensity(context);
  if (mapTilerKey.isNotEmpty) {
    final id = dark ? mapTilerStyleDark : mapTilerStyleLight;
    return TileLayer(
      urlTemplate: 'https://api.maptiler.com/maps/$id/256/{z}/{x}/{y}{r}.png?key=$mapTilerKey',
      retinaMode: retina,
      userAgentPackageName: 'dz.nqata.client',
      maxNativeZoom: 19,
    );
  }
  final style = dark ? 'dark_all' : 'light_all';
  final key = cartoKey.isEmpty ? '' : '?key=$cartoKey';
  return TileLayer(
    urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}{r}.png$key',
    retinaMode: retina,
    userAgentPackageName: 'dz.nqata.client',
    maxNativeZoom: 19,
  );
}

/// Mention obligatoire selon le fournisseur : à garder visible sur toutes les cartes.
Widget get mapAttribution => SimpleAttributionWidget(
      source: Text(mapTilerKey.isNotEmpty ? '© MapTiler · © OpenStreetMap contributors' : '© OpenStreetMap · © CARTO', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
    );

const _cats = {
  'all': ['Tous', 'الكل'],
  'fav': ['Favoris', 'المفضلة'],
  'cafe': ['Café', 'مقهى'],
  'food': ['Alimentation', 'مواد غذائية'],
  'health': ['Santé', 'صحة'],
  'beauty': ['Beauté', 'تجميل'],
  'other': ['Autres', 'أخرى'],
};

/// Carte : même charte que le Profil et les Offres (en-tête sombre, feuille arrondie,
/// cartes teintées), recherche, filtres, position de l'utilisateur, fiche du commerce touché.
class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final mc = MapController();
  String query = '', cat = 'all';
  String? selected; // id du commerce touché sur la carte

  // ---------- Style commun (mêmes valeurs que profile.dart) ----------
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => _ink.withOpacity(0.62);
  Color get _gold => _dark ? brandYellow : brandLight;
  Color get _link => _dark ? brandYellow : const Color(0xFF8A6500);
  Color get _tint => _dark ? const Color(0xFF1B1912) : const Color(0xFFF6F3EA);
  (String, String, Color, Color) get _cover => coverThemes[store.coverTheme % coverThemes.length];

  // ---------- Données ----------
  LatLng _pt(Map<String, dynamic> s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble());
  int _offers(Map<String, dynamic> s) => store.offers.where((o) => o['shop_id'] == s['id']).length;

  void _msg(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _locate() async {
    HapticFeedback.selectionClick();
    await store.locate(ask: true);
    if (!mounted) return;
    final me = store.me;
    if (me == null) {
      _msg(tr('Autorisez la localisation pour voir les commerces proches', 'اسمح بالموقع لرؤية المحلات القريبة'));
      return;
    }
    mc.move(me, 14);
  }

  void _open(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s, km: store.km(s))));

  String? _hour(String? hours, int g) {
    if (hours == null) return null;
    final m = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})\s*[–—-]\s*(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(hours);
    if (m == null) return null;
    return '${m[g]!.padLeft(2, '0')}:${m[g + 1]}';
  }

  /// « Ouvre à 08:00 » / « Ouvert jusqu'à 20:00 » + distance
  String _info(Map<String, dynamic> s) {
    final h = s['hours'] as String?;
    final open = openNow(h);
    final km = store.km(s);
    final base = open == null ? (h ?? '') : open ? tr('Ouvert jusqu\'à ${_hour(h, 3)}', 'مفتوح حتى ${_hour(h, 3)}') : tr('Ouvre à ${_hour(h, 1)}', 'يفتح عند ${_hour(h, 1)}');
    return '$base${km == null ? '' : (base.isEmpty ? '' : ' • ') + '${km.toStringAsFixed(1)} km'}';
  }

  // ---------- En-tête sombre (comme le Profil) ----------
  Widget _glassButton({required String icon, String? label, required String semantics, required VoidCallback onTap}) => Semantics(
        button: true,
        label: semantics,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 44,
            constraints: const BoxConstraints(minWidth: 44),
            padding: EdgeInsetsDirectional.symmetric(horizontal: label == null ? 0 : 14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white30)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              NIcon(icon, size: 20, color: Colors.white, accent: brandYellow),
              if (label != null) ...[const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600))],
            ]),
          ),
        ),
      );

  Widget _catChip(String key, List<String> label) {
    final sel = cat == key;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        selected: sel,
        label: tr(label[0], label[1]),
        child: Pressable(
          onTap: () { HapticFeedback.selectionClick(); setState(() { cat = key; selected = null; }); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? brandYellow : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? brandYellow : Colors.white24),
            ),
            child: Text(tr(label[0], label[1]), style: TextStyle(color: sel ? Colors.black87 : Colors.white, fontSize: 13.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _header(double top, List<Map<String, dynamic>> items) {
    final cv = _cover;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 16),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cv.$3, cv.$4])),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(tr('Carte', 'الخريطة'), style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : -0.4))),
          _glassButton(icon: 'list', label: tr('Liste', 'قائمة'), semantics: tr('Afficher la liste des commerces', 'عرض قائمة المحلات'), onTap: () => _list(items)),
        ]),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() { query = v; selected = null; }),
          cursorColor: brandYellow,
          style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.10),
            hintText: tr('Rechercher un commerce', 'ابحث عن محل'),
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: NIcon('search', size: 22, color: Colors.white, accent: brandYellow)),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: brandYellow, width: 1.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [for (final e in _cats.entries) _catChip(e.key, e.value)])),
      ]),
    );
  }

  // ---------- Carte ----------
  Marker _marker(Map<String, dynamic> s) {
    final id = '${s['id']}';
    final sel = selected == id;
    final fav = store.favs.contains(id);
    final closed = openNow(s['hours'] as String?) == false;
    final size = sel ? 52.0 : 42.0;
    return Marker(
      point: _pt(s),
      width: 60,
      height: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selected = id);
          mc.move(_pt(s), mc.camera.zoom);
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? brandDark : (closed ? const Color(0xFFB8B4A8) : brandYellow),
              border: Border.all(color: sel ? brandYellow : brandDark, width: sel ? 3 : 2.5),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              NIcon(catIcon(s['category'] as String?), size: sel ? 26 : 21, color: sel ? brandYellow : brandDark, accent: Colors.white),
              if (fav)
                PositionedDirectional(
                  top: -5,
                  end: -5,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: brandDark, width: 1.5)),
                    child: const NIcon('star_fill', size: 11, color: Colors.amber, accent: Colors.amber),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Marker _meMarker(LatLng me) => Marker(
        point: me,
        width: 46,
        height: 46,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: brandYellow.withOpacity(0.28)),
          child: Container(width: 18, height: 18, decoration: BoxDecoration(color: brandDark, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
        ),
      );

  /// Rond flottant sur la carte (localisation), avec une ombre légère pour rester lisible.
  Widget _mapButton(String icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _tint, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))]),
            child: NIcon(icon, size: 24, color: _ink, accent: _gold),
          ),
        ),
      );

  /// Fiche du commerce touché : même carte teintée que dans les Offres.
  Widget _selectedCard(Map<String, dynamic> s) {
    final n = _offers(s);
    final r = store.ratings['${s['id']}'];
    return Pressable(
      onTap: () => _open(s),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4))]),
        child: Row(children: [
          ShopLogo(shop: s, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
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
                if (n > 0) ...[
                  const SizedBox(width: 8),
                  NIcon('tag', size: 14, color: _link, accent: _link),
                  const SizedBox(width: 3),
                  Text('$n', style: TextStyle(color: _link, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ]),
              const SizedBox(height: 6),
              Text(_info(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(color: brandYellow, shape: BoxShape.circle), child: const NIcon('chevron', size: 20, color: Colors.black87, accent: Colors.black87)),
        ]),
      ),
    );
  }

  // ---------- Liste (feuille du bas) ----------
  void _list(List<Map<String, dynamic>> items) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheet).size.height * 0.65,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('${tr('Commerces', 'المحلات')} (${items.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: lang == 'ar' ? 0 : -0.2)),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(tr('Aucun commerce trouvé', 'لا توجد نتائج'), style: TextStyle(color: _muted)))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                        for (final s in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Pressable(
                              onTap: () { Navigator.pop(sheet); _open(s); },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(18)),
                                child: Row(children: [
                                  ShopLogo(shop: s, size: 48),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text([if (store.km(s) != null) '${store.km(s)!.toStringAsFixed(1)} km', '${s['address'] ?? ''}'].where((e) => e.isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: _muted)),
                                    ]),
                                  ),
                                  if (store.favs.contains('${s['id']}')) const NIcon('star_fill', size: 20, color: Colors.amber, accent: Colors.amber),
                                ]),
                              ),
                            ),
                          ),
                      ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // icônes de la barre d'état claires sur l'en-tête sombre
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final top = MediaQuery.of(context).padding.top;
            final all = store.shops.where((s) => s['lat'] != null && s['lng'] != null).toList();
            final items = all.where((s) {
              if (!'${s['name']}'.toLowerCase().contains(query.toLowerCase())) return false;
              if (cat == 'all') return true;
              return cat == 'fav' ? store.favs.contains('${s['id']}') : s['category'] == cat;
            }).toList();
            final me = store.me;
            if (me != null) items.sort((a, b) => store.km(a)!.compareTo(store.km(b)!));
            final sel = selected == null ? null : items.where((s) => '${s['id']}' == selected).firstOrNull;
            final center = me ??
                (all.isEmpty
                    ? const LatLng(36.7538, 3.0588)
                    : LatLng(all.map((s) => (s['lat'] as num).toDouble()).reduce((a, b) => a + b) / all.length,
                        all.map((s) => (s['lng'] as num).toDouble()).reduce((a, b) => a + b) / all.length));
            // le commerce sélectionné est dessiné en dernier : il reste au-dessus des autres
            final markers = [for (final s in items) if (s != sel) _marker(s), if (sel != null) _marker(sel)];
            return Column(children: [
              FadeSlideIn(child: _header(top, items)),
              Expanded(
                // le fond sombre n'apparaît que derrière les coins arrondis de la carte
                child: Container(
                  color: _cover.$4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Stack(children: [
                      FlutterMap(
                        mapController: mc,
                        key: ValueKey(all.length),
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                          minZoom: 3,
                          maxZoom: 19,
                          onTap: (_, __) { if (selected != null) setState(() => selected = null); },
                        ),
                        children: [
                          nqataTiles(context),
                          MarkerLayer(markers: [...markers, if (me != null) _meMarker(me)]),
                          mapAttribution,
                        ],
                      ),
                      if (all.isNotEmpty)
                        PositionedDirectional(
                          top: 12,
                          start: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))]),
                            child: Text('${items.length} ${tr('commerce(s)', 'محل')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      AnimatedPositionedDirectional(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        end: 12,
                        bottom: sel != null ? 140 : 36,
                        child: _mapButton('locate', tr('Ma position', 'موقعي'), _locate),
                      ),
                      if (sel != null) PositionedDirectional(start: 12, end: 12, bottom: 30, child: FadeSlideIn(key: ValueKey('card-${sel['id']}'), child: _selectedCard(sel))),
                      if (all.isEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(18)),
                            child: Text(tr('Aucun commerce placé sur la carte', 'لا توجد محلات على الخريطة')),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}
