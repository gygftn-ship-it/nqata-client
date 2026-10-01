import 'package:flutter/material.dart';
import 'main.dart';
import 'shop.dart';
import 'tabs.dart';

/// Centre de notifications : filtres, regroupement par jour, ouverture du commerce concerné.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Set<dynamic> fresh = store.notifsShown.where((n) => n['read_at'] == null).map((n) => n['id']).toSet();
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    store.markAllRead(); // les nouvelles restent surlignées pendant cette visite
  }

  static String _kind(Map<String, dynamic> n) {
    final b = '${n['body'] ?? ''}';
    if (b.startsWith('+')) return 'points';
    if (b.contains('Récompense')) return 'rewards';
    if (b.toLowerCase().contains('offre')) return 'offers';
    return 'other';
  }

  static (IconData, Color) _style(String k) => switch (k) {
        'points' => (Icons.stars_rounded, Colors.green),
        'rewards' => (Icons.card_giftcard_rounded, Colors.amber.shade700),
        'offers' => (Icons.local_offer_rounded, Colors.pink),
        _ => (Icons.notifications_rounded, Colors.blueGrey),
      };

  static String _day(DateTime d) {
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    return diff == 0 ? tr('Aujourd\'hui', 'اليوم') : diff == 1 ? tr('Hier', 'أمس') : '${d.day}/${d.month}/${d.year}';
  }

  void _open(Map<String, dynamic> n) {
    final s = store.shops.where((x) => x['name'] == n['title']).toList();
    if (s.isNotEmpty) Navigator.push(context, smoothRoute(ShopPage(shop: s.first)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final theme = Theme.of(context);
          final list = store.notifsShown.where((n) => filter == 'all' || _kind(n) == filter).toList();
          DateTime at(int i) => DateTime.parse('${list[i]['created_at']}').toLocal();
          return Scaffold(
            appBar: AppBar(
              title: Text(tr('Notifications', 'الإشعارات')),
              actions: [IconButton(icon: const Icon(Icons.done_all), tooltip: tr('Tout marquer comme lu', 'تحديد الكل كمقروء'), onPressed: store.markAllRead)],
            ),
            body: Column(children: [
              SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
                  for (final f in const [('all', 'Tout', 'الكل'), ('points', 'Points', 'النقاط'), ('rewards', 'Récompenses', 'المكافآت'), ('offers', 'Offres', 'العروض')])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: Text(tr(f.$2, f.$3)), selected: filter == f.$1, onSelected: (_) => setState(() => filter = f.$1)),
                    ),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Column(children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.elasticOut,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: const Icon(Icons.notifications_off_outlined, size: 72, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Text(tr('Rien pour le moment', 'لا شيء حاليًا'), style: theme.textTheme.titleMedium),
                          Text(tr('Vos points, récompenses et offres apparaîtront ici.', 'ستظهر هنا نقاطك ومكافآتك وعروضك.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        ]),
                      ),
                    for (var i = 0; i < list.length; i++) ...[
                      if (i == 0 || _day(at(i)) != _day(at(i - 1)))
                        Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(_day(at(i)), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
                      FadeSlideIn(
                        index: i,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _open(list[i]),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: fresh.contains(list[i]['id']) ? brandLight.withOpacity(0.14) : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              CircleAvatar(backgroundColor: _style(_kind(list[i])).$2, child: Icon(_style(_kind(list[i])).$1, color: Colors.white, size: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${list[i]['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${list[i]['body'] ?? ''}'),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('${at(i).hour.toString().padLeft(2, '0')}:${at(i).minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (fresh.contains(list[i]['id'])) Container(margin: const EdgeInsets.only(top: 6), width: 9, height: 9, decoration: const BoxDecoration(color: brandLight, shape: BoxShape.circle)),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
          );
        },
      );
}
