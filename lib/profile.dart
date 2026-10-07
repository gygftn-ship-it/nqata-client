import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'nicons.dart';
import 'extras.dart';
import 'home.dart'; // Pressable
import 'main.dart';
import 'notifs.dart';
import 'policy.dart';
import 'referral.dart';
import 'tabs.dart';
import 'wallet.dart';

const supportEmail = 'support@nqata.app'; // ← remplacez par votre vraie adresse de support
const appVersion = '0.1.0';

const avatarColors = [Color(0xFF15120B), Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF475569)];

/// Thèmes d'en-tête du profil : (nom FR, nom AR, haut du dégradé, bas du dégradé).
const coverThemes = [
  ('Or', 'ذهبي', Color(0xFF15120B), Color(0xFF2B2108)),
  ('Violet', 'بنفسجي', Color(0xFF1B0F33), Color(0xFF3B1A78)),
  ('Océan', 'محيط', Color(0xFF0B1B30), Color(0xFF14407A)),
  ('Forêt', 'غابة', Color(0xFF0A2219), Color(0xFF0F5C4F)),
  ('Rose', 'وردي', Color(0xFF2A0A1C), Color(0xFF8E1A52)),
  ('Graphite', 'رمادي', Color(0xFF0E0E10), Color(0xFF2F3440)),
];

/// Niveau de fidélité selon le nombre de visites (utilisé aussi par l'accueil).
Map<String, dynamic> levelInfo() {
  final v = store.txs.where((t) => t['type'] == 'visit' && t['undone'] != true).length;
  if (v >= 20) return {'emoji': '🥇', 'name': tr('Or', 'ذهبي'), 'from': 20, 'next': null, 'next_name': '', 'color': const Color(0xFFF59E0B), 'visits': v};
  if (v >= 5) return {'emoji': '🥈', 'name': tr('Argent', 'فضي'), 'from': 5, 'next': 20, 'next_name': tr('Or', 'الذهبي'), 'color': const Color(0xFF9CA3AF), 'visits': v};
  return {'emoji': '🥉', 'name': tr('Bronze', 'برونزي'), 'from': 0, 'next': 5, 'next_name': tr('Argent', 'الفضي'), 'color': const Color(0xFFCD7F32), 'visits': v};
}

// =====================================================================
//  Style commun
// =====================================================================
bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color _line(BuildContext c) => _ink(c).withOpacity(_isDark(c) ? 0.14 : 0.10);
Color _muted(BuildContext c) => _ink(c).withOpacity(0.62);
Color _gold(BuildContext c) => _isDark(c) ? brandYellow : brandLight;
Color _tint(BuildContext c) => _isDark(c) ? const Color(0xFF1B1912) : const Color(0xFFF6F3EA); // fond des tuiles et listes

/// Groupe de lignes dans une carte teintée aux grands arrondis.
Widget _group(BuildContext c, List<Widget> rows) => ListTileTheme(
      data: ListTileThemeData(
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink(c)),
        subtitleTextStyle: TextStyle(fontSize: 12.5, color: _muted(c)),
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Material(
        color: _tint(c),
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(22),
        child: Column(children: rows),
      ),
    );

Widget _title(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10, left: 4, right: 4),
      child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: lang == 'ar' ? 0 : -0.2)),
    );

Widget _row(BuildContext c, String icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap, bool danger = false}) => ListTile(
      onTap: onTap,
      leading: NIcon(icon, size: 24, color: danger ? Colors.red : _ink(c), accent: danger ? Colors.red.shade200 : _gold(c)),
      title: Text(title, style: danger ? const TextStyle(color: Colors.red) : null),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? (onTap != null ? NIcon('chevron', size: 18, color: _ink(c), accent: _ink(c)) : null),
    );

Widget _switchRow(BuildContext c, String icon, String title, String subtitle, bool value, void Function(bool) onChanged, {bool enabled = true}) => _row(
      c, icon, title,
      subtitle: subtitle,
      trailing: Switch(value: value && enabled, onChanged: enabled ? (v) { HapticFeedback.selectionClick(); onChanged(v); } : null),
      onTap: enabled ? () { HapticFeedback.selectionClick(); onChanged(!value); } : null,
    );

Widget _choice(BuildContext c, String icon, String title, Widget control) => Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NIcon(icon, size: 24, color: _ink(c), accent: _gold(c)),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: control),
      ]),
    );

/// Bouton rond (paramètres, retour). [onDark] : version claire pour l'en-tête sombre.
Widget _roundBtn(BuildContext c, String icon, String label, VoidCallback onTap, {bool onDark = false}) => Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onDark ? Colors.white.withOpacity(0.10) : _tint(c),
            border: onDark ? Border.all(color: Colors.white24) : null,
          ),
          child: NIcon(icon, size: 22, color: onDark ? Colors.white : _ink(c), accent: onDark ? brandYellow : _gold(c)),
        ),
      ),
    );

// =====================================================================
//  Actions partagées
// =====================================================================
void _snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
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

Future<void> _editProfile(BuildContext context) async {
  final c = TextEditingController(text: store.name);
  var color = store.avatarColor % avatarColors.length;
  var avatarId = store.avatarId;
  var cover = store.coverTheme % coverThemes.length;
  final initial = store.name.isEmpty ? '?' : store.name[0].toUpperCase();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (_, set) {
        final onSurface = Theme.of(sheet).colorScheme.onSurface;
        Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)));
        Widget dot({required bool on, required VoidCallback tap, Color? fill, Gradient? grad, Widget? child}) => GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); tap(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: fill, gradient: grad, border: Border.all(color: on ? onSurface : Colors.transparent, width: 3)),
                child: child,
              ),
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Personnaliser mon profil', 'تخصيص ملفي'), style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              Center(child: NAvatar(id: avatarId, initial: initial, color: avatarColors[color], size: 84)),
              const SizedBox(height: 16),
              TextField(controller: c, decoration: InputDecoration(labelText: tr('Prénom ou pseudo', 'الاسم'), border: const OutlineInputBorder())),
              label(tr('Avatar', 'الصورة الرمزية')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final id in ['', ...avatarIds])
                  GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); set(() => avatarId = id); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: avatarId == id ? onSurface : Colors.transparent, width: 3)),
                      child: NAvatar(id: id, initial: initial, color: avatarColors[color], size: 52),
                    ),
                  ),
              ]),
              // la couleur ne sert qu'au fond de l'initiale
              if (avatarId.isEmpty) ...[
                label(tr('Couleur de l\'initiale', 'لون الحرف')),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (var i = 0; i < avatarColors.length; i++)
                    dot(on: color == i, tap: () => set(() => color = i), fill: avatarColors[i], child: color == i ? const NIcon('check', color: Colors.white) : null),
                ]),
              ],
              label(tr('Thème de l\'en-tête', 'لون الواجهة العلوية')),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < coverThemes.length; i++)
                  dot(
                    on: cover == i,
                    tap: () => set(() => cover = i),
                    grad: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [coverThemes[i].$3, coverThemes[i].$4]),
                    child: cover == i ? const NIcon('check', color: Colors.white) : null,
                  ),
              ]),
              const SizedBox(height: 6),
              Text(tr(coverThemes[cover].$1, coverThemes[cover].$2), style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.62))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final n = c.text.trim();
                    try {
                      if (n.isNotEmpty && n != store.name) await store.rename(n);
                      store.setAvatarColor(color);
                      store.setAvatarId(avatarId);
                      store.setCoverTheme(cover);
                      if (sheet.mounted) Navigator.pop(sheet);
                    } catch (err) {
                      _snack(context, errText(err));
                    }
                  },
                  child: Text(tr('Enregistrer', 'حفظ')),
                ),
              ),
            ]),
          ),
        );
      },
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

Future<void> _contactSupport(BuildContext context) async {
  final uri = Uri(scheme: 'mailto', path: supportEmail, queryParameters: {'subject': 'Nqata – ${store.name}', 'body': '\n\n---\n${store.email} · ${store.code}'});
  try {
    if (await launchUrl(uri)) return;
  } catch (_) {}
  Clipboard.setData(const ClipboardData(text: supportEmail));
  if (context.mounted) _snack(context, tr('Aucune app e-mail trouvée : adresse copiée ($supportEmail)', 'لا يوجد تطبيق بريد: تم نسخ العنوان ($supportEmail)'));
}

void _export(BuildContext context) {
  final data = {
    'compte': {'nom': store.name, 'email': store.email, 'code_client': store.code},
    'points_par_commerce': [for (final r in store.wallet) {'commerce': (r['shops'] as Map?)?['name'], 'points': r['points']}],
    'transactions': store.txs,
  };
  Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
  _snack(context, tr('Vos données ont été copiées : collez-les où vous voulez', 'تم نسخ بياناتك: الصقها حيث تريد'));
}

// =====================================================================
//  ÉCRAN PROFIL (onglet)
//  En-tête sombre (avatar, nom, niveau, ⚙️) + carte de progression jaune,
//  puis une feuille claire aux coins arrondis : tuiles de raccourcis et liste.
//  Les réglages sont dans SettingsPage, ouverte par le bouton ⚙️.
// =====================================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Bouton « ⚙ Paramètres » : icône + texte, pour qu'on comprenne tout de suite à quoi il sert.
  Widget _settingsButton(BuildContext c) => Semantics(
        button: true,
        label: tr('Paramètres', 'الإعدادات'),
        child: Pressable(
          onTap: () => Navigator.push(c, smoothRoute(const SettingsPage())),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 16, 9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const NIcon('settings', size: 20, color: Colors.white, accent: brandYellow),
              const SizedBox(width: 8),
              Text(tr('Paramètres', 'الإعدادات'), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _header(BuildContext c, Map<String, dynamic> lv) {
    final lvColor = lv['color'] as Color;
    final cv = coverThemes[store.coverTheme % coverThemes.length];
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(c).padding.top + 14, 20, 22),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cv.$3, cv.$4])),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(tr('Profil', 'الملف'), style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : -0.4))),
          _settingsButton(c),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          GestureDetector(
            onTap: () => _editProfile(c),
            child: Stack(children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: lvColor, width: 2)),
                child: NAvatar(id: store.avatarId, size: 60, color: avatarColors[store.avatarColor % avatarColors.length], initial: store.name.isEmpty ? '?' : store.name[0].toUpperCase()),
              ),
              // petit crayon : indique que l'avatar se personnalise en le touchant
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: brandYellow, shape: BoxShape.circle, border: Border.all(color: cv.$4, width: 2)),
                  child: const NIcon('edit', size: 12, color: Colors.black87, accent: Colors.black87),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(store.name.isEmpty ? '…' : store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                NIcon('trophy', size: 18, color: lvColor, accent: Colors.white),
                const SizedBox(width: 4),
                Text('${lv['name']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 2),
              Text(store.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        _levelBanner(lv),
      ]),
    );
  }

  /// Carte jaune (comme la bannière promo de l'app d'inspiration) : niveau + progression + points.
  Widget _levelBanner(Map<String, dynamic> lv) {
    final next = lv['next'] as int?, from = lv['from'] as int, visits = lv['visits'] as int;
    final progress = next == null ? 1.0 : ((visits - from) / (next - from)).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tr('Membre', 'عضو')} ${lv['name']}', style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              next == null ? tr('Niveau maximum atteint', 'وصلت لأعلى مستوى') : '${next - visits} ${tr('visites avant le niveau', 'زيارات قبل المستوى')} ${lv['next_name']}',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 6, color: Colors.black87, backgroundColor: Colors.black12)),
            ),
          ]),
        ),
        const SizedBox(width: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedCount(store.total, style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
          Text('${tr('points', 'نقطة')} · ${store.wallet.length} ${tr('commerce(s)', 'متجر')}', style: const TextStyle(color: Colors.black87, fontSize: 11.5)),
        ]),
      ]),
    );
  }

  /// Tuile de raccourci (icône + libellé), fond teinté sans contour.
  Widget _tile(BuildContext c, String icon, String label, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 6),
            decoration: BoxDecoration(color: _tint(c), borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              width: double.infinity,
              child: Column(children: [
                NIcon(icon, size: 28, color: _ink(c), accent: _gold(c)),
                const SizedBox(height: 10),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: brandYellow, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // icônes de la barre d'état claires sur l'en-tête sombre
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final lv = levelInfo();
            return ListView(padding: EdgeInsets.zero, children: [
              FadeSlideIn(child: _header(context, lv)),
              // le fond sombre n'apparaît que derrière les coins arrondis de la feuille
              Container(
                color: coverThemes[store.coverTheme % coverThemes.length].$4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(children: [
                    FadeSlideIn(
                      index: 1,
                      child: Row(children: [
                        _tile(context, 'history', tr('Historique', 'السجل'), () => Navigator.push(context, smoothRoute(const HistoryPage()))),
                        const SizedBox(width: 10),
                        _tile(context, 'bell', tr('Notifications', 'الإشعارات'), () => Navigator.push(context, smoothRoute(const NotificationsPage()))),
                        const SizedBox(width: 10),
                        _tile(context, 'help', tr('Aide', 'المساعدة'), () => Navigator.push(context, smoothRoute(const HelpPage()))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 2,
                      child: _group(context, [
                        _row(context, 'user', tr('Personnaliser mon profil', 'تخصيص ملفي'), subtitle: tr('Nom, avatar et couleurs', 'الاسم والصورة والألوان'), onTap: () => _editProfile(context)),
                        _row(context, 'hash', tr('Mon code client', 'رمز الزبون'), subtitle: store.code.isEmpty ? '—' : store.code, trailing: NIcon('copy', size: 20, color: _ink(context), accent: _gold(context)), onTap: () {
                          if (store.code.isEmpty) return;
                          Clipboard.setData(ClipboardData(text: store.code));
                          _snack(context, tr('Code copié', 'تم نسخ الرمز'));
                        }),
                        _row(context, 'gift', tr('Parrainage', 'الترشيح'), trailing: _pill(tr('Inviter un ami', 'ادعُ صديقًا')), onTap: () => Navigator.push(context, smoothRoute(const ReferralPage()))),
                        // Support : désactivé pour l'instant. Pour le réactiver, remplacer par : onTap: () => _contactSupport(context)
                        _row(context, 'support', tr('Contacter le support', 'اتصل بالدعم'), subtitle: tr('Bientôt disponible', 'قريبًا')),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}

// =====================================================================
//  PAGE PARAMÈTRES (ouverte depuis le bouton ⚙️ du profil)
// =====================================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: store,
            builder: (_, __) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              FadeSlideIn(
                child: Row(children: [
                  _roundBtn(context, 'back', tr('Retour', 'رجوع'), () => Navigator.pop(context)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(tr('Paramètres', 'الإعدادات'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: lang == 'ar' ? 0 : -0.4))),
                ]),
              ),
              _title(context, tr('Sécurité', 'الأمان')),
              FadeSlideIn(
                index: 1,
                child: _group(context, [
                  const PinSettingsTile(),
                  if (store.hasPin)
                    _switchRow(context, 'fingerprint', tr('Déverrouiller avec l\'empreinte', 'الفتح بالبصمة'), tr('Au lieu de saisir le code PIN', 'بدل إدخال رمز PIN'), store.bioEnabled, (v) async {
                      try {
                        await store.setBio(v);
                      } catch (e) {
                        _snack(context, errText(e));
                      }
                    }),
                  _row(context, 'password', tr('Changer le mot de passe', 'تغيير كلمة السر'), onTap: () => _changePassword(context)),
                  _row(context, 'devices', tr('Se déconnecter de tous les appareils', 'تسجيل الخروج من كل الأجهزة'), onTap: () async {
                    if (await _confirm(context, tr('Déconnexion partout', 'خروج من كل الأجهزة'), tr('Vous serez déconnecté de tous vos appareils, y compris celui-ci.', 'سيتم تسجيل خروجك من كل أجهزتك بما فيها هذا الجهاز.'), tr('Déconnecter', 'خروج'))) {
                      await store.signOutEverywhere();
                    }
                  }),
                ]),
              ),
              _title(context, tr('Notifications', 'الإشعارات')),
              FadeSlideIn(
                index: 2,
                child: _group(context, [
                  _switchRow(context, 'bell', tr('Notifications activées', 'الإشعارات مفعّلة'), tr('Tout activer ou tout désactiver', 'تفعيل أو إيقاف الكل'), store.notifsOn, (v) => store.setNotifsOn(v)),
                  _switchRow(context, 'coin', tr('Points gagnés', 'النقاط المكتسبة'), tr('À chaque visite', 'عند كل زيارة'), store.nPoints, (v) => store.setNotifPref('points', v), enabled: store.notifsOn),
                  _switchRow(context, 'gift', tr('Récompenses', 'المكافآت'), tr('Récompense débloquée ou utilisée', 'مكافأة مفتوحة أو مستخدمة'), store.nRewards, (v) => store.setNotifPref('rewards', v), enabled: store.notifsOn),
                  _switchRow(context, 'tag', tr('Offres des commerces', 'عروض المتاجر'), tr('Vos commerces et favoris', 'متاجرك ومفضلتك'), store.nOffers, (v) => store.setNotifPref('offers', v), enabled: store.notifsOn),
                ]),
              ),
              _title(context, tr('Apparence et langue', 'المظهر واللغة')),
              FadeSlideIn(
                index: 3,
                child: _group(context, [
                  _choice(
                    context,
                    'contrast',
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
                    context,
                    'globe',
                    tr('Langue', 'اللغة'),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [ButtonSegment(value: 'fr', label: Text('Français')), ButtonSegment(value: 'ar', label: Text('العربية'))],
                      selected: {lang},
                      onSelectionChanged: (s) => store.setLang(s.first),
                    ),
                  ),
                  _choice(
                    context,
                    'text',
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
              ),
              _title(context, tr('Confidentialité et données', 'الخصوصية والبيانات')),
              FadeSlideIn(
                index: 4,
                child: _group(context, [
                  _row(context, 'pin', tr('Autorisation de localisation', 'إذن الموقع'), subtitle: tr('Gérer dans les réglages du téléphone', 'إدارة من إعدادات الهاتف'), onTap: () => Geolocator.openAppSettings()),
                  _row(context, 'download', tr('Exporter mes données', 'تصدير بياناتي'), subtitle: tr('Copie votre compte, vos points et vos transactions', 'ينسخ حسابك ونقاطك ومعاملاتك'), onTap: () => _export(context)),
                  _row(context, 'shield', tr('Politique de confidentialité', 'سياسة الخصوصية'), onTap: () => Navigator.push(context, smoothRoute(const PolicyPage()))),
                  _row(context, 'doc', tr('Conditions d\'utilisation', 'شروط الاستخدام'), onTap: () => _info(context, tr('Conditions d\'utilisation', 'شروط الاستخدام'), tr(
                    'Nqata est un service de cartes de fidélité entre des clients et des commerces partenaires. Les points appartiennent au programme de chaque commerce, qui peut en fixer les règles (points par visite, seuil de récompense). Vous êtes responsable de la confidentialité de vos identifiants et de votre code PIN. Ces conditions sont provisoires et seront complétées avant la publication.',
                    'نقطة خدمة بطاقات ولاء بين الزبائن والمتاجر الشريكة. النقاط تابعة لبرنامج كل متجر الذي يحدد قواعده (نقاط الزيارة، حد المكافأة). أنت مسؤول عن سرية بيانات دخولك ورمز PIN. هذه الشروط مؤقتة وسيتم استكمالها قبل النشر.'))),
                ]),
              ),
              _title(context, tr('À propos', 'حول')),
              FadeSlideIn(
                index: 5,
                child: _group(context, [
                  _row(context, 'info', 'Nqata', subtitle: '${tr('Version', 'الإصدار')} $appVersion'),
                  _row(context, 'doc', tr('Licences', 'التراخيص'), onTap: () => showLicensePage(context: context, applicationName: 'Nqata', applicationVersion: appVersion)),
                ]),
              ),
              _title(context, tr('Compte', 'الحساب')),
              FadeSlideIn(
                index: 6,
                child: _group(context, [
                  _row(context, 'logout', tr('Se déconnecter', 'تسجيل الخروج'), onTap: () async {
                    if (await _confirm(context, tr('Se déconnecter ?', 'تسجيل الخروج؟'), tr('Vous pourrez vous reconnecter à tout moment.', 'يمكنك الدخول مجددًا في أي وقت.'), tr('Déconnexion', 'خروج'))) {
                      await store.signOut();
                      if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
                    }
                  }),
                  _row(context, 'trash', tr('Supprimer mon compte', 'حذف حسابي'), danger: true, onTap: () async {
                    if (await _confirm(context, tr('Supprimer mon compte ?', 'حذف حسابي؟'), tr('Votre compte, vos points et votre historique seront supprimés définitivement.', 'سيتم حذف حسابك ونقاطك وسجلك نهائيًا.'), tr('Supprimer', 'حذف'), danger: true)) {
                      try {
                        await store.deleteAccount();
                        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
                      } catch (e) {
                        _snack(context, errText(e));
                      }
                    }
                  }),
                ]),
              ),
              const SizedBox(height: 24),
              Center(child: Text('Nqata $appVersion', style: TextStyle(color: _muted(context), fontSize: 12))),
            ]),
          ),
        ),
      );
}
