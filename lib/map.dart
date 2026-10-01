import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'main.dart';
import 'shop.dart';

const _cats = {
  'all': ['Tous', 'الكل'],
  'fav': ['⭐ Favoris', '⭐ المفضلة'],
  'cafe': ['Café', 'مقهى'],
  'food': ['Alimentation', 'مواد غذائية'],
  'health': ['Santé', 'صحة'],
  'beauty': ['Beauté', 'تجميل'],
  'other': ['Autres', 'أخرى'],
};

/// Carte : recherche, filtres, position de l'utilisateur, tri par distance.
class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final mc = MapController();
  String query = '', cat = 'all';
  LatLng? me;

  LatLng _pt(Map<String, dynamic> s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble());
  double? _km(Map<String, dynamic> s) => me == null ? null : const Distance().distance(me!, _pt(s)) / 1000;

  void _msg(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _msg(tr('Autorisez la localisation pour voir les commerces proches', 'اسمح بالموقع لرؤية المحلات القريبة'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => me = LatLng(pos.latitude, pos.longitude));
      mc.move(me!, 14);
    } catch (_) {
      _msg(tr('Position indisponible', 'الموقع غير متاح'));
    }
  }

  void _open(Map<String, dynamic> s) => Navigator.push(context, smoothRoute(ShopPage(shop: s, km: _km(s))));

  void _list(List<Map<String, dynamic>> items) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: items.isEmpty
              ? Center(child: Text(tr('Aucun commerce trouvé', 'لا توجد نتائج')))
              : ListView(children: [
                  for (final s in items)
                    ListTile(
                      leading: CircleAvatar(child: Icon(catIcon(s['category'] as String?))),
                      title: Text('${s['name']}'),
                      subtitle: Text([if (_km(s) != null) '${_km(s)!.toStringAsFixed(1)} km', '${s['address'] ?? ''}'].join(' · ')),
                      trailing: store.favs.contains('${s['id']}') ? const Icon(Icons.star, color: Colors.amber) : null,
                      onTap: () { Navigator.pop(context); _open(s); },
                    ),
                ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final all = store.shops.where((s) => s['lat'] != null && s['lng'] != null).toList();
          final items = all.where((s) {
            if (!'${s['name']}'.toLowerCase().contains(query.toLowerCase())) return false;
            if (cat == 'all') return true;
            return cat == 'fav' ? store.favs.contains('${s['id']}') : s['category'] == cat;
          }).toList();
          if (me != null) items.sort((a, b) => _km(a)!.compareTo(_km(b)!));
          final center = me ??
              (all.isEmpty
                  ? const LatLng(36.7538, 3.0588)
                  : LatLng(all.map((s) => (s['lat'] as num).toDouble()).reduce((a, b) => a + b) / all.length,
                      all.map((s) => (s['lng'] as num).toDouble()).reduce((a, b) => a + b) / all.length));
          return Stack(children: [
            FlutterMap(
              mapController: mc,
              key: ValueKey(all.length),
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dz.nqata.client'),
                MarkerLayer(markers: [
                  for (final s in items)
                    Marker(
                      point: _pt(s),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _open(s),
                        child: Icon(Icons.location_on, color: store.favs.contains('${s['id']}') ? Colors.amber.shade700 : brandDark, size: 44),
                      ),
                    ),
                  if (me != null)
                    Marker(
                      point: me!,
                      width: 22,
                      height: 22,
                      child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
                    ),
                ]),
                const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Rechercher un commerce', 'ابحث عن محل'),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final e in _cats.entries)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(label: Text(tr(e.value[0], e.value[1])), selected: cat == e.key, onSelected: (_) => setState(() => cat = e.key)),
                      ),
                  ]),
                ),
              ]),
            ),
            PositionedDirectional(
              bottom: 16,
              end: 16,
              child: Column(children: [
                FloatingActionButton.small(heroTag: 'loc', onPressed: _locate, child: const Icon(Icons.my_location)),
                const SizedBox(height: 10),
                FloatingActionButton.extended(heroTag: 'lst', onPressed: () => _list(items), icon: const Icon(Icons.list), label: Text(tr('Liste', 'قائمة'))),
              ]),
            ),
            if (all.isEmpty) Center(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(tr('Aucun commerce placé sur la carte', 'لا توجد محلات على الخريطة'))))),
          ]);
        },
      );
}
