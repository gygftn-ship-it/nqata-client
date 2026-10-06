import 'package:flutter/material.dart';
import 'main.dart';
import 'nicons.dart';
import 'tabs.dart';

/// Classement amical : uniquement entre un parrain et ses filleuls (jamais public).
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<Map<String, dynamic>>> rows = store.friendLeaderboard();

  static const _medal = [Color(0xFFFFD60A), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Classement entre amis', 'الترتيب بين الأصدقاء'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? const [];
          if (list.length <= 1) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const NIcon('groups', size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(tr('Invitez un ami pour commencer un classement', 'ادعُ صديقًا لبدء ترتيب'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(tr('Le classement ne compare que vous et les personnes que vous avez parrainées (ou qui vous ont parrainé).', 'يقارن الترتيب بينك وبين من رشحتهم (أو من رشّحك) فقط.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ]),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async { setState(() => rows = store.friendLeaderboard()); await rows; },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  index: i,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: list[i]['is_me'] == true ? brandYellow.withOpacity(0.18) : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: list[i]['is_me'] == true ? Border.all(color: brandYellow, width: 2) : null,
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 32,
                        child: i < 3
                            ? NIcon('trophy', color: _medal[i], size: 26)
                            : Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(backgroundColor: brandDark, child: Text('${list[i]['display_name']}'.isEmpty ? '?' : '${list[i]['display_name']}'[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(children: [
                          Text('${list[i]['display_name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: list[i]['is_me'] == true ? 16 : 15)),
                          if (list[i]['is_me'] == true) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Text(tr('(vous)', '(أنت)'), style: const TextStyle(color: Colors.grey, fontSize: 12))),
                        ]),
                      ),
                      if ((list[i]['streak_weeks'] as int) > 0) ...[
                        const NIcon('bolt', size: 16, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text('${list[i]['streak_weeks']}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                      ],
                      Text('${list[i]['total_points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
