import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'nicons.dart';
import 'tabs.dart';

/// Parrainage : inviter un ami, ou saisir le code de qui vous a invité.
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});
  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final code = TextEditingController();
  late Future<Map<String, dynamic>> stats = store.referralStats();
  bool busy = false;

  @override
  void dispose() { code.dispose(); super.dispose(); }

  Future<void> _apply() async {
    if (code.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final name = await store.applyReferral(code.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Parrain ajouté :', 'تمت إضافة الراعي:')} $name')));
      code.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
    if (mounted) setState(() => busy = false);
  }

  void _share() {
    final text = tr(
      'Rejoins-moi sur Nqata avec mon code ${store.code} et gagne des points fidélité chez tes commerces préférés !',
      'انضم إلي على نقطة برمزي ${store.code} واكسب نقاط ولاء في متاجرك المفضلة!',
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Message copié : collez-le dans WhatsApp', 'تم النسخ: الصقه في واتساب'))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alreadyHasOne = store.referredBy;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Parrainage', 'الترشيح'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [brandDark, brandLight])),
            child: Column(children: [
              NIcon('gift', size: 44, color: Colors.white, accent: Colors.amber),
              const SizedBox(height: 10),
              Text(tr('Invitez vos amis', 'ادعُ أصدقاءك'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(tr('Quand un ami visite un commerce participant avec votre code, vous gagnez tous les deux des points.', 'عندما يزور صديق متجرًا مشاركًا برمزك، تكسبان كلاكما نقاطًا.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                child: Text(store.code.isEmpty ? '······' : store.code, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandDark),
                onPressed: _share,
                icon: NIcon('share', size: 18),
                label: Text(tr('Partager mon code', 'مشاركة رمزي')),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 1,
          child: FutureBuilder<Map<String, dynamic>>(
            future: stats,
            builder: (_, snap) {
              final friends = snap.data?['friends'] ?? 0, paid = snap.data?['paid'] ?? 0;
              return Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                    child: Column(children: [Text('$friends', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(tr('Amis invités', 'أصدقاء مدعوون'), style: const TextStyle(fontSize: 12))]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                    child: Column(children: [Text('$paid', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(tr('Bonus reçus', 'المكافآت المستلمة'), style: const TextStyle(fontSize: 12))]),
                  ),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 24),
        if (alreadyHasOne)
          Text(tr('Vous avez déjà un parrain.', 'لديك راعٍ بالفعل.'), style: const TextStyle(color: Colors.grey))
        else ...[
          Text(tr('On vous a invité ?', 'هل دعاك أحد؟'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(tr('Saisissez le code avant votre première visite chez un commerçant.', 'أدخل الرمز قبل أول زيارة لمتجر.'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: tr('Code de votre ami', 'رمز صديقك'), border: const OutlineInputBorder()))),
            const SizedBox(width: 8),
            FilledButton(onPressed: busy ? null : _apply, child: Text(tr('Valider', 'تأكيد'))),
          ]),
        ],
      ]),
    );
  }
}
