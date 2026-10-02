import 'dart:convert';
import 'package:flutter/material.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'extras.dart';
import 'main.dart';
import 'tabs.dart';
import 'wallet.dart';

const supportEmail = ''; // ← à renseigner : l'e-mail du support Nqata (le bouton « Contacter le support » l'utilisera)

const avatarColors = [Color(0xFF15120B), Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF475569)];

void _snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

/// Niveau de fidélité selon le nombre de visites.
Map<String, dynamic> levelInfo() {
  final v = store.txs.where((t) => t['type'] == 'visit' && t['undone'] != true).length;
  if (v >= 20) return {'emoji': '🥇', 'name': tr('Or', 'ذهبي'), 'from': 20, 'next': null, 'next_name': '', 'color': const Color(0xFFF59E0B), 'visits': v};
  if (v >= 5) return {'emoji': '🥈', 'name': tr('Argent', 'فضي'), 'from': 5, 'next': 20, 'next_name': tr('Or', 'الذهبي'), 'color': const Color(0xFF9CA3AF), 'visits': v};
  return {'emoji': '🥉', 'name': tr('Bronze', 'برونزي'), 'from': 0, 'next': 5, 'next_name': tr('Argent', 'الفضي'), 'color': const Color(0xFFCD7F32), 'visits': v};
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  // ---------- Actions ----------
  Future<void> _editProfile(BuildContext context) async {
    final c = TextEditingController(text: store.name);
    var color = store.avatarColor;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (_, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Modifier mon profil', 'تعديل ملفي'), style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: c, decoration: InputDecoration(labelText: tr('Prénom ou pseudo', 'الاسم'), border: const OutlineInputBorder())),
            const SizedBox(height: 16),
            Text(tr('Couleur de l\'avatar', 'لون الصورة الرمزية')),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < avatarColors.length; i++)
                GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); set(() => color = i); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: avatarColors[i], shape: BoxShape.circle, border: Border.all(color: color == i ? Colors.black87 : Colors.transparent, width: 3)),
                    child: color == i ? const NIcon('check', color: Colors.white) : null,
                  ),
                ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final n = c.text.trim();
                  try {
                    if (n.isNotEmpty && n != store.name) await store.rename(n);
                    store.setAvatarColor(color);
                    if (sheet.mounted) Navigator.pop(sheet);
                  } catch (e) {
                    _snack(context, errText(e));
                  }
                },
                child: Text(tr('Enregistrer', 'حفظ')),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final a = TextEditingController(), b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Changer le mot de passe', 'تغيير كلمة السر')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, obscureText: true, decoration: InputDecoration(labelText: tr('Nouveau mot de passe (6 caractères min.)', 'كلمة السر الجديدة (6 أحرف على الأقل)'))),
          const SizedBox(height: 10),
          TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: tr('Confirmer', 'تأكيد'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Modifier', 'تغيير'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (a.text.length < 6 || a.text != b.text) {
      _snack(context, tr('Les mots de passe ne correspondent pas, ou sont trop courts', 'كلمتا السر غير متطابقتين أو قصيرتان'));
      return;
    }
    try {
      await store.changePassword(a.text);
      _snack(context, tr('Mot de passe modifié', 'تم تغيير كلمة السر'));
    } catch (e) {
      _snack(context, errText(e));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action, {bool danger = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
            FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null, onPressed: () => Navigator.pop(d, true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  void _info(BuildContext context, String title, String body) => showDialog(
        context: context,
        builder: (d) => AlertDialog(title: Text(title), content: SingleChildScrollView(child: Text(body)), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))]),
      );

  void _export(BuildContext context) {
    final data = {
      'compte': {'nom': store.name, 'email': store.email, 'code_client': store.code},
      'points_par_commerce': [for (final r in store.wallet) {'commerce': (r['shops'] as Map?)?['name'], 'points': r['points']}],
      'transactions': store.txs,
    };
    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    _snack(context, tr('Vos données ont été copiées : collez-les où vous voulez', 'تم نسخ بياناتك: الصقها حيث تريد'));
  }

  // ---------- Éléments de présentation ----------
  Widget _stat(int v, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            AnimatedCount(v, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      );

  Widget _header(BuildContext context) {
    final lv = levelInfo();
    final next = lv['next'] as int?, from = lv['from'] as int, visits = lv['visits'] as int;
    final progress = next == null ? 1.0 : ((visits - from) / (next - from)).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(children: [
        Row(children: [
          Text(tr('Profil', 'الملف'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const NIcon('edit', color: Colors.white), onPressed: () => _editProfile(context)),
        ]),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [Colors.white, lv['color'] as Color, Colors.white])),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: avatarColors[store.avatarColor % avatarColors.length],
              child: Text(store.name.isEmpty ? '?' : store.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(store.name.isEmpty ? '…' : store.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(store.email, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(children: [
              NIcon('trophy', size: 24, color: lv['color'] as Color, accent: Colors.white),
              const SizedBox(width: 8),
              Text('${tr('Membre', 'عضو')} ${lv['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(next == null ? tr('Niveau maximum', 'أعلى مستوى') : '$visits / $next ${tr('visites', 'زيارات')}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: Colors.white24, color: lv['color'] as Color)),
            ),
            if (next != null) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: Text('${next - visits} ${tr('visites avant le niveau', 'زيارات قبل المستوى')} ${lv['next_name']}', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _stat(store.total, tr('Points', 'نقاط')),
          const SizedBox(width: 10),
          _stat(store.wallet.length, tr('Commerces', 'متاجر')),
          const SizedBox(width: 10),
          _stat(store.rewardsReady.length, tr('Récompenses', 'مكافآت')),
        ]),
      ]),
    );
  }

  Widget _section(BuildContext context, int i, String title, List<Widget> tiles) => FadeSlideIn(
        index: i,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8), child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1))),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                for (var k = 0; k < tiles.length; k++) ...[if (k > 0) const Divider(height: 1, indent: 60), tiles[k]],
              ]),
            ),
          ]),
        ),
      );

  Widget _icon(String icon, Color color) => Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: NIcon(icon, color: Colors.white, size: 20));

  Widget _tile(String icon, Color color, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) => ListTile(
        onTap: onTap,
        leading: _icon(icon, color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: trailing ?? (onTap != null ? const NIcon('chevron') : null),
      );

  Widget _switch(String icon, Color color, String title, String subtitle, bool value, void Function(bool) onChanged) =>
      _tile(icon, color, title, subtitle: subtitle, trailing: Switch(value: value, onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); }), onTap: () { HapticFeedback.selectionClick(); onChanged(!value); });

  Widget _choice(String icon, Color color, String title, Widget control) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_icon(icon, color), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: control),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => ListView(padding: EdgeInsets.zero, children: [
          _header(context),
          _section(context, 0, tr('Compte', 'الحساب'), [
            _tile('user', Colors.teal, tr('Modifier mon profil', 'تعديل ملفي'), subtitle: tr('Nom et couleur de l\'avatar', 'الاسم ولون الصورة'), onTap: () => _editProfile(context)),
            _tile('at', Colors.blue, tr('E-mail', 'البريد'), subtitle: store.email),
            _tile('hash', Colors.indigo, tr('Mon code client', 'رمز الزبون'), subtitle: store.code.isEmpty ? '—' : store.code, trailing: const NIcon('copy', size: 20), onTap: () {
              if (store.code.isEmpty) return;
              Clipboard.setData(ClipboardData(text: store.code));
              _snack(context, tr('Code copié', 'تم نسخ الرمز'));
            }),
          ]),
          _section(context, 1, tr('Sécurité', 'الأمان'), [
            const PinSettingsTile(),
            _tile('password', Colors.orange, tr('Changer le mot de passe', 'تغيير كلمة السر'), onTap: () => _changePassword(context)),
            _tile('devices', Colors.deepPurple, tr('Se déconnecter de tous les appareils', 'تسجيل الخروج من كل الأجهزة'), onTap: () async {
              if (await _confirm(context, tr('Déconnexion partout', 'خروج من كل الأجهزة'), tr('Vous serez déconnecté de tous vos appareils, y compris celui-ci.', 'سيتم تسجيل خروجك من كل أجهزتك بما فيها هذا الجهاز.'), tr('Déconnecter', 'خروج'))) {
                await store.signOutEverywhere();
              }
            }),
          ]),
          _section(context, 2, tr('Notifications', 'الإشعارات'), [
            _switch('coin', Colors.green, tr('Points gagnés', 'النقاط المكتسبة'), tr('À chaque visite', 'عند كل زيارة'), store.nPoints, (v) => store.setNotifPref('points', v)),
            _switch('gift', Colors.amber.shade700, tr('Récompenses', 'المكافآت'), tr('Récompense débloquée ou utilisée', 'مكافأة مفتوحة أو مستخدمة'), store.nRewards, (v) => store.setNotifPref('rewards', v)),
            _switch('tag', Colors.pink, tr('Offres des commerces', 'عروض المتاجر'), tr('Vos commerces et favoris', 'متاجرك ومفضلتك'), store.nOffers, (v) => store.setNotifPref('offers', v)),
            _tile('bell', Colors.grey, tr('Notifications quand l\'app est fermée', 'إشعارات عند إغلاق التطبيق'), subtitle: tr('Bientôt disponible', 'قريبًا')),
          ]),
          _section(context, 3, tr('Apparence et langue', 'المظهر واللغة'), [
            _choice(
              'contrast',
              Colors.blueGrey,
              tr('Thème', 'السمة'),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(tr('Auto', 'تلقائي'))),
                  ButtonSegment(value: ThemeMode.light, label: Text(tr('Clair', 'فاتح'))),
                  ButtonSegment(value: ThemeMode.dark, label: Text(tr('Sombre', 'داكن'))),
                ],
                selected: {store.themeMode},
                onSelectionChanged: (s) => store.setThemeMode(s.first),
              ),
            ),
            _choice(
              'globe',
              Colors.cyan.shade700,
              tr('Langue', 'اللغة'),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'fr', label: Text('Français')), ButtonSegment(value: 'ar', label: Text('العربية'))],
                selected: {lang},
                onSelectionChanged: (s) => store.setLang(s.first),
              ),
            ),
            _choice(
              'text',
              Colors.brown,
              tr('Taille du texte', 'حجم النص'),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1.0, label: Text('Aa', style: TextStyle(fontSize: 13))),
                  ButtonSegment(value: 1.15, label: Text('Aa', style: TextStyle(fontSize: 16))),
                  ButtonSegment(value: 1.3, label: Text('Aa', style: TextStyle(fontSize: 19))),
                ],
                selected: {store.textScale},
                onSelectionChanged: (s) => store.setTextScale(s.first),
              ),
            ),
          ]),
          _section(context, 4, tr('Confidentialité et données', 'الخصوصية والبيانات'), [
            _tile('pin', Colors.red, tr('Autorisation de localisation', 'إذن الموقع'), subtitle: tr('Gérer dans les réglages du téléphone', 'إدارة من إعدادات الهاتف'), onTap: () => Geolocator.openAppSettings()),
            _tile('download', Colors.teal, tr('Exporter mes données', 'تصدير بياناتي'), subtitle: tr('Copie votre compte, vos points et vos transactions', 'ينسخ حسابك ونقاطك ومعاملاتك'), onTap: () => _export(context)),
            _tile('shield', Colors.blue, tr('Confidentialité', 'الخصوصية'), onTap: () => _info(context, tr('Confidentialité', 'الخصوصية'), tr(
              'Nqata ne conserve que votre prénom ou pseudo et votre e-mail. Les commerçants voient seulement votre pseudo, votre solde et vos visites chez eux, jamais votre activité ailleurs. Vous pouvez exporter ou supprimer votre compte et toutes vos données à tout moment depuis cet écran.',
              'تحتفظ نقطة فقط باسمك أو لقبك وبريدك الإلكتروني. يرى التجار لقبك ورصيدك وزياراتك لديهم فقط، ولا يرون نشاطك في أماكن أخرى. يمكنك تصدير أو حذف حسابك وكل بياناتك في أي وقت من هذه الشاشة.'))),
            _tile('doc', Colors.grey.shade700, tr('Conditions d\'utilisation', 'شروط الاستخدام'), onTap: () => _info(context, tr('Conditions d\'utilisation', 'شروط الاستخدام'), tr(
              'Nqata est un service de cartes de fidélité entre des clients et des commerces partenaires. Les points appartiennent au programme de chaque commerce, qui peut en fixer les règles (points par visite, seuil de récompense). Vous êtes responsable de la confidentialité de vos identifiants et de votre code PIN. Ces conditions sont provisoires et seront complétées avant la publication.',
              'نقطة خدمة بطاقات ولاء بين الزبائن والمتاجر الشريكة. النقاط تابعة لبرنامج كل متجر الذي يحدد قواعده (نقاط الزيارة، حد المكافأة). أنت مسؤول عن سرية بيانات دخولك ورمز PIN. هذه الشروط مؤقتة وسيتم استكمالها قبل النشر.'))),
          ]),
          _section(context, 5, tr('Aide', 'المساعدة'), [
            _tile('history', Colors.purple, tr('Historique complet', 'السجل الكامل'), onTap: () => Navigator.push(context, smoothRoute(const HistoryPage()))),
            _tile('help', Colors.green, tr('Aide et questions fréquentes', 'المساعدة والأسئلة الشائعة'), onTap: () => Navigator.push(context, smoothRoute(const HelpPage()))),
            _tile('support', Colors.blue, tr('Contacter le support', 'اتصل بالدعم'), onTap: () {
              if (supportEmail.isEmpty) {
                _info(context, tr('Support', 'الدعم'), tr('Le contact du support sera bientôt disponible dans l\'application.', 'سيتوفر الاتصال بالدعم قريبًا في التطبيق.'));
              } else {
                launchUrl(Uri.parse('mailto:$supportEmail?subject=Nqata'));
              }
            }),
          ]),
          _section(context, 6, tr('À propos', 'حول'), [
            _tile('info', Colors.grey, 'Nqata', subtitle: '${tr('Version', 'الإصدار')} 0.1.0'),
            _tile('doc', Colors.grey.shade600, tr('Licences', 'التراخيص'), onTap: () => showLicensePage(context: context, applicationName: 'Nqata', applicationVersion: '0.1.0')),
          ]),
          _section(context, 7, tr('Compte', 'الحساب'), [
            _tile('logout', Colors.blueGrey, tr('Se déconnecter', 'تسجيل الخروج'), onTap: () async {
              if (await _confirm(context, tr('Se déconnecter ?', 'تسجيل الخروج؟'), tr('Vous pourrez vous reconnecter à tout moment.', 'يمكنك الدخول مجددًا في أي وقت.'), tr('Déconnexion', 'خروج'))) await store.signOut();
            }),
            ListTile(
              onTap: () async {
                if (await _confirm(context, tr('Supprimer mon compte ?', 'حذف حسابي؟'), tr('Votre compte, vos points et votre historique seront supprimés définitivement.', 'سيتم حذف حسابك ونقاطك وسجلك نهائيًا.'), tr('Supprimer', 'حذف'), danger: true)) {
                  try {
                    await store.deleteAccount();
                  } catch (e) {
                    _snack(context, errText(e));
                  }
                }
              },
              leading: _icon('trash', Colors.red),
              title: Text(tr('Supprimer mon compte', 'حذف حسابي'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(child: Text('Nqata 0.1.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 24),
        ]),
      );
}
