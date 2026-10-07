import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Jeu d'icônes Nqata : trait noir épais aux bouts arrondis + un « point » jaune dans chaque icône
/// (nqata = « point » : c'est notre signature, comme la pièce et les yeux de la mascotte).
const _ink = Color(0xFF15120B);
const _yellow = Color(0xFFFFD60A);

// Les corps d'icônes (grille 24×24). {A} = couleur du point d'accent, {C} = couleur du trait.
const _icons = <String, String>{
  'pin': r'<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4" fill="{A}" stroke="none"/>',
  'card': r'<rect x="3" y="6" width="18" height="12.5" rx="3"/><path d="M3 10.5h18"/><circle cx="7.5" cy="14.8" r="1.4" fill="{A}" stroke="none"/>',
  'tag': r'<path d="M3.5 12.5V5.5a2 2 0 0 1 2-2h7l8 8a2 2 0 0 1 0 2.8l-6.2 6.2a2 2 0 0 1-2.8 0z"/><circle cx="8.3" cy="8.3" r="1.8" fill="{A}" stroke="none"/>',
  'groups': r'<circle cx="9" cy="8.5" r="3" fill="{A}"/><circle cx="16.5" cy="9.5" r="2.4"/><path d="M3.5 19c.6-3.3 2.8-5 5.5-5s4.9 1.7 5.5 5M15 14.2c2.6-.3 4.6 1.2 5.5 4.3"/>',
  'bell': r'<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 21h4"/><circle cx="12" cy="4" r="1.3" fill="{A}" stroke="none"/>',
  'bell_off': r'<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 21h4M4 4l16 16"/><circle cx="12" cy="4" r="1.3" fill="{A}" stroke="none"/>',
  'qr': r'<rect x="3.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.6"/><path d="M14 14h2.5M20.5 14v2.5M14 17.5v3M17.5 20.5h3"/><circle cx="17.5" cy="17" r="1.4" fill="{A}" stroke="none"/>',
  'history': r'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/><circle cx="12" cy="12" r="1.4" fill="{A}" stroke="none"/>',
  'star_fill': r'<path d="M12 3.8l2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8z" fill="{A}"/>',
  'share': r'<circle cx="6" cy="12" r="2.3" fill="{A}"/><circle cx="18" cy="6" r="2.3"/><circle cx="18" cy="18" r="2.3"/><path d="M8 11l8-4M8 13l8 4"/>',
  'directions': r'<path d="M12 3.5 20.5 12 12 20.5 3.5 12z"/><path d="M9 14v-2.5a1 1 0 0 1 1-1h4.5M12.8 8.2l1.9 2.3-1.9 2.3"/>',
  'search': r'<circle cx="10.5" cy="10.5" r="6"/><path d="M15.5 15.5 20 20"/><circle cx="10.5" cy="10.5" r="1.8" fill="{A}" stroke="none"/>',
  'lock': r'<rect x="5" y="10.5" width="14" height="9.5" rx="3"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/><circle cx="12" cy="15.3" r="1.6" fill="{A}" stroke="none"/>',
  'lock_open': r'<rect x="5" y="10.5" width="14" height="9.5" rx="3"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 6.6-1.6"/><circle cx="12" cy="15.3" r="1.6" fill="{A}" stroke="none"/>',
  'shield': r'<path d="M12 3.5 19 6v5.5c0 4.3-3 7.6-7 9-4-1.4-7-4.7-7-9V6z"/><circle cx="12" cy="11.5" r="2" fill="{A}" stroke="none"/>',
  'gift': r'<rect x="4" y="9" width="16" height="11" rx="2.5"/><path d="M3.5 9h17M12 9v11M12 9C9.5 9 8 8 8 6.6S9.6 4.7 12 9zM12 9c2.5 0 4-1 4-2.4S14.4 4.7 12 9z"/><circle cx="8" cy="14.5" r="1.3" fill="{A}" stroke="none"/>',
  'coin': r'<circle cx="12" cy="12" r="8.5" fill="{A}"/><path d="M9.2 16V8l5.6 8V8"/>',
  'trophy': r'<path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H5.5a2 2 0 0 0 2 4M16 6h2.5a2 2 0 0 1-2 4M12 13v4M8.5 20h7"/><circle cx="12" cy="7.5" r="1.4" fill="{A}" stroke="none"/>',
  'edit': r'<path d="M5 19l1-4L16 5l3 3L9 18z"/><path d="M14 7l3 3"/><circle cx="6.2" cy="17.8" r="1.1" fill="{A}" stroke="none"/>',
  'copy': r'<rect x="8.5" y="8.5" width="11" height="11" rx="2.5"/><path d="M15.5 8.5V6.5a2 2 0 0 0-2-2h-7a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h2"/><circle cx="14" cy="14" r="1.4" fill="{A}" stroke="none"/>',
  'logout': r'<path d="M10 4H6.5A2.5 2.5 0 0 0 4 6.5v11A2.5 2.5 0 0 0 6.5 20H10"/><path d="M14 8l4 4-4 4M9 12h9"/><circle cx="18" cy="12" r="1.3" fill="{A}" stroke="none"/>',
  'trash': r'<path d="M5 7h14M10 4h4M7 7l.8 12a2 2 0 0 0 2 1.9h4.4a2 2 0 0 0 2-1.9L17 7"/><circle cx="12" cy="13.5" r="1.5" fill="{A}" stroke="none"/>',
  'globe': r'<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.4 3.6 5.2 3.6 8.5S14.5 18.1 12 20.5M12 3.5C9.5 5.9 8.4 8.7 8.4 12S9.5 18.1 12 20.5"/><circle cx="15.6" cy="8.6" r="1.3" fill="{A}" stroke="none"/>',
  'help': r'<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.6a2.6 2.6 0 0 1 4.9 1.1c0 1.7-2.5 2-2.5 3.4"/><circle cx="12" cy="16.8" r="1.2" fill="{A}" stroke="none"/>',
  'store': r'<path d="M4 9.5 5.5 4.5h13L20 9.5"/><path d="M4 9.5a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0"/><path d="M5.5 12.5V20h13v-7.5"/><rect x="10" y="14.5" width="4" height="5.5" rx="1" fill="{A}"/>',
  'basket': r'<path d="M3.5 10h17l-1.6 9a2 2 0 0 1-2 1.6H7.1a2 2 0 0 1-2-1.6z"/><path d="M8 10l3-6M16 10l-3-6"/><circle cx="12" cy="15" r="1.5" fill="{A}" stroke="none"/>',
  'cafe': r'<path d="M5 9h11v5a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5z"/><path d="M16 10.5h1.5a2.5 2.5 0 0 1 0 5H16M8 3.5c-.8 1 .8 1.7 0 2.8M12 3.5c-.8 1 .8 1.7 0 2.8"/><circle cx="10.5" cy="13.5" r="1.4" fill="{A}" stroke="none"/>',
  'medical': r'<rect x="4" y="7" width="16" height="12" rx="3"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7M12 10.5v5M9.5 13h5"/><circle cx="12" cy="13" r="1.3" fill="{A}" stroke="none"/>',
  'scissors': r'<circle cx="6.5" cy="6.5" r="2.5" fill="{A}"/><circle cx="6.5" cy="17.5" r="2.5"/><path d="M8.7 7.8 20 18M8.7 16.2 20 6"/>',
  'fingerprint': r'<path d="M12 11v3.5c0 2-.5 3.8-1.6 5.5M8 8.5A5 5 0 0 1 17 11v2.5c0 1.6-.2 3-.7 4.4M5.5 12c0-.7.1-1.4.3-2M9 14.5c0 1.6-.3 2.9-.9 4M15 15c0 1.5-.2 2.6-.5 3.5"/><circle cx="12" cy="11" r="1.4" fill="{A}" stroke="none"/>',
  'chevron': r'<path d="M9.5 6l6 6-6 6"/>',
  'drop': r'<path d="M7 10l5 5 5-5"/>',
  'check': r'<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  'refresh': r'<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3M19.5 4.5v4h-4"/><circle cx="12" cy="12" r="1.3" fill="{A}" stroke="none"/>',
  'list': r'<path d="M8.5 6.5h11M8.5 12h11M8.5 17.5h11"/><circle cx="4.8" cy="6.5" r="1.3" fill="{A}" stroke="none"/><circle cx="4.8" cy="12" r="1.3" fill="{A}" stroke="none"/><circle cx="4.8" cy="17.5" r="1.3" fill="{A}" stroke="none"/>',
  'nfc': r'<path d="M8.5 8.5a5 5 0 0 1 0 7M12 6a8.5 8.5 0 0 1 0 12M15.5 3.5a12 12 0 0 1 0 17"/>',
  'wifi_off': r'<path d="M3.5 9a13 13 0 0 1 17 0M6.5 12.5a8.5 8.5 0 0 1 11 0M9.5 15.8a4 4 0 0 1 5 0M4 4l16 16"/><circle cx="12" cy="19" r="1.3" fill="{A}" stroke="none"/>',
  'check_circle': r'<circle cx="12" cy="12" r="8.5" fill="{A}"/><path d="M8 12.3l2.8 2.8L16.3 9.5"/>',
  'locate': r'<circle cx="12" cy="12" r="3.5" fill="{A}"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3"/>',
  'backspace': r'<path d="M20 6H9l-5.5 6L9 18h11a1 1 0 0 0 1-1V7a1 1 0 0 0-1-1z"/><path d="M12.5 9.5l5 5M17.5 9.5l-5 5"/>',
  'done_all': r'<path d="M3 12.5l4 4L15 8M10 15l1.5 1.5L21 7.5"/>',
  'bolt': r'<path d="M13 3.5 6 13h5l-1 7.5L18 11h-5z" fill="{A}"/>',
  'home': r'<path d="M3.5 11 12 4l8.5 7"/><path d="M5.5 10v9.5h13V10"/><circle cx="12" cy="15.5" r="2" fill="{A}" stroke="none"/>',
  'wallet': r'<path d="M5.5 6.5h11A3.5 3.5 0 0 1 20 10v6.5a3 3 0 0 1-3 3H6.5a3 3 0 0 1-3-3V8.5a2 2 0 0 1 2-2z"/><path d="M5.5 6.5 16 4.5"/><circle cx="16.5" cy="13.5" r="1.9" fill="{A}" stroke="none"/>',
  'user': r'<path d="M5 20c.8-3.6 3.5-5.5 7-5.5s6.2 1.9 7 5.5"/><circle cx="12" cy="8" r="3.6" fill="{A}"/>',
  'star': r'<path d="M12 3.8l2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/>',
  'support': r'<path d="M5 14v-2a7 7 0 0 1 14 0v2"/><rect x="3.5" y="13" width="3.5" height="5.5" rx="1.5"/><rect x="17" y="13" width="3.5" height="5.5" rx="1.5"/><path d="M19 18.5c0 1.5-1.5 2.5-4 2.5"/><circle cx="14.5" cy="21" r="1.1" fill="{A}" stroke="none"/>',
  'info': r'<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5"/><circle cx="12" cy="7.9" r="1.2" fill="{A}" stroke="none"/>',
  'doc': r'<path d="M7 3.5h7l4 4V19a1.5 1.5 0 0 1-1.5 1.5h-9.5A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/><path d="M14 3.5V8h4M8.5 12.5h7M8.5 16h4.5"/><circle cx="16.3" cy="16" r="1.2" fill="{A}" stroke="none"/>',
  'download': r'<path d="M12 4v10M7.5 10 12 14.5 16.5 10M5 19h14"/><circle cx="12" cy="19" r="1.4" fill="{A}" stroke="none"/>',
  'at': r'<circle cx="12" cy="12" r="3.4" fill="{A}"/><path d="M15.4 12v1.6a2.4 2.4 0 0 0 4.8 0V12a8.2 8.2 0 1 0-3.2 6.5"/>',
  'hash': r'<path d="M9 4 7.5 20M16.5 4 15 20M4.5 9h15M4 15h15"/><circle cx="12" cy="12" r="1.4" fill="{A}" stroke="none"/>',
  'password': r'<rect x="3.5" y="8" width="17" height="8.5" rx="3"/><circle cx="8" cy="12.3" r="1.2" fill="{A}" stroke="none"/><circle cx="12" cy="12.3" r="1.2" fill="{A}" stroke="none"/><circle cx="16" cy="12.3" r="1.2" fill="{A}" stroke="none"/>',
  'devices': r'<rect x="3.5" y="6" width="12" height="9" rx="2"/><path d="M2 18.5h15"/><rect x="17" y="9" width="4" height="9" rx="1.2"/><circle cx="19" cy="15.8" r="0.9" fill="{A}" stroke="none"/>',
  'text': r'<path d="M4.5 18 9 6l4.5 12M6 14h6"/><path d="M15 18l2.5-6.5L20 18M15.8 16h3.4"/><circle cx="17.5" cy="9" r="1.2" fill="{A}" stroke="none"/>',
  'contrast': r'<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5a8.5 8.5 0 0 1 0 17z" fill="{A}"/>',
  'back': r'<path d="M19 12H5M11 6l-6 6 6 6"/>',
  'add': r'<path d="M12 5v14M5 12h14"/>',
  'block': r'<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>',
  'settings': r'<circle cx="12" cy="12" r="3.2" fill="{A}"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
  'near': r'<path d="M20 4 4.5 10.5l6 2.5 2.5 6z"/><circle cx="10.2" cy="12.8" r="1.2" fill="{A}" stroke="none"/>',
};

String _hex(Color c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Icône Nqata (même utilisation que `Icon`) : `NIcon('home', size: 24, color: ..., accent: ...)`.
class NIcon extends StatelessWidget {
  final String name;
  final double? size;
  final Color? color; // trait
  final Color? accent; // le « point » (jaune par défaut)
  const NIcon(this.name, {super.key, this.size, this.color, this.accent});

  static const _mirror = {'chevron', 'back'}; // inversées en arabe (droite → gauche)

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? _ink;
    final a = accent ?? _yellow;
    final body = (_icons[name] ?? _icons['coin']!).replaceAll('{A}', _hex(a)).replaceAll('{C}', _hex(c));
    final alpha = (c.value >> 24) / 255;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(c)}" stroke-opacity="$alpha" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    final icon = SvgPicture.string(svg, width: s, height: s);
    return Directionality.of(context) == TextDirection.rtl && _mirror.contains(name) ? Transform.flip(flipX: true, child: icon) : icon;
  }
}

/// La mascotte dans un médaillon blanc (écrans vides, messages).
class RobotBadge extends StatelessWidget {
  final double size;
  const RobotBadge({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _yellow, width: 4), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))]),
        child: ClipOval(child: Image.asset('robot.png', fit: BoxFit.contain)),
      );
}

// ---------------------------------------------------------------------
//  Avatars illustrés (dessinés en SVG, aucune image à ajouter au projet)
// ---------------------------------------------------------------------
class _Av {
  final String style; // short, long, bun, curly, cap, hijab
  final Color bg, skin, hair, shirt, accent; // accent : couleur du foulard (hijab) ou de la casquette (cap)
  final bool glasses, beard;
  const _Av(this.style, {required this.bg, required this.skin, required this.hair, required this.shirt, this.accent = const Color(0xFF15120B), this.glasses = false, this.beard = false});
}

const _avatars = [
  _Av('short', bg: Color(0xFFFDE68A), skin: Color(0xFFE0AC82), hair: Color(0xFF2B2118), shirt: Color(0xFF3B82F6)),
  _Av('short', bg: Color(0xFFBFDBFE), skin: Color(0xFFC68B5E), hair: Color(0xFF1F1A14), shirt: Color(0xFF15120B), beard: true),
  _Av('cap', bg: Color(0xFFBBF7D0), skin: Color(0xFFF5D0B0), hair: Color(0xFF5A3A1E), shirt: Color(0xFFEF4444), accent: Color(0xFF15120B)),
  _Av('short', bg: Color(0xFFFBCFE8), skin: Color(0xFF8D5A3B), hair: Color(0xFF15120B), shirt: Color(0xFF14B8A6), glasses: true),
  _Av('long', bg: Color(0xFFDDD6FE), skin: Color(0xFFE0AC82), hair: Color(0xFF2B1A12), shirt: Color(0xFFEC4899)),
  _Av('hijab', bg: Color(0xFFFDE68A), skin: Color(0xFFF5D0B0), hair: Color(0xFF2B2118), shirt: Color(0xFF15120B), accent: Color(0xFF7C3AED)),
  _Av('hijab', bg: Color(0xFFFED7AA), skin: Color(0xFFC68B5E), hair: Color(0xFF2B2118), shirt: Color(0xFFF59E0B), accent: Color(0xFF14B8A6)),
  _Av('bun', bg: Color(0xFFA5F3FC), skin: Color(0xFF8D5A3B), hair: Color(0xFF15120B), shirt: Color(0xFFF59E0B)),
  _Av('curly', bg: Color(0xFFFDE68A), skin: Color(0xFF5C3A24), hair: Color(0xFF15120B), shirt: Color(0xFF7C3AED)),
  _Av('long', bg: Color(0xFFBBF7D0), skin: Color(0xFFF5D0B0), hair: Color(0xFFB45309), shirt: Color(0xFF3B82F6), glasses: true),
  _Av('hijab', bg: Color(0xFFBFDBFE), skin: Color(0xFFE0AC82), hair: Color(0xFF2B2118), shirt: Color(0xFF475569), accent: Color(0xFFEC4899)),
  _Av('short', bg: Color(0xFFE5E7EB), skin: Color(0xFFE0AC82), hair: Color(0xFF5A3A1E), shirt: Color(0xFF15120B), beard: true, glasses: true),
];

/// Identifiants proposés dans le sélecteur : 'a0'…'a11' + la mascotte Nqata. ('' = simple initiale)
const avatarIds = ['a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'robot'];

String _avatarSvg(_Av a) {
  const ink = '#2B2118';
  final skin = _hex(a.skin), hair = _hex(a.hair), shirt = _hex(a.shirt), acc = _hex(a.accent);
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">')
    ..write('<rect width="100" height="100" fill="${_hex(a.bg)}"/>');
  if (a.style == 'long') b.write('<path d="M27 50C23 22 77 22 73 50L76 80H24Z" fill="$hair"/>');
  b.write('<path d="M14 100C14 80 31 72 50 72S86 80 86 100Z" fill="$shirt"/>');
  if (a.style == 'hijab') {
    b.write('<path d="M24 54C20 18 80 18 76 54C78 72 72 84 62 90H38C28 84 22 72 24 54Z" fill="$acc"/>');
    b.write('<ellipse cx="50" cy="52" rx="15.5" ry="17.5" fill="$skin"/>');
    b.write('<circle cx="44.5" cy="52" r="1.9" fill="$ink"/><circle cx="55.5" cy="52" r="1.9" fill="$ink"/>');
    b.write('<path d="M44.5 60Q50 64.5 55.5 60" fill="none" stroke="$ink" stroke-width="2" stroke-linecap="round"/>');
  } else {
    b.write('<rect x="44" y="60" width="12" height="16" rx="5" fill="$skin"/>');
    b.write('<circle cx="50" cy="46" r="20" fill="$skin"/>');
    if (a.beard) b.write('<path d="M30 50C30 76 70 76 70 50C66 62 34 62 30 50Z" fill="$hair"/>');
    b.write('<circle cx="43" cy="47" r="1.9" fill="$ink"/><circle cx="57" cy="47" r="1.9" fill="$ink"/>');
    b.write('<path d="M43.5 56Q50 62 56.5 56" fill="none" stroke="$ink" stroke-width="2" stroke-linecap="round"/>');
    switch (a.style) {
      case 'short':
        b.write('<path d="M30 46C27 21 73 21 70 46C66 36 58 31 50 31S34 36 30 46Z" fill="$hair"/>');
      case 'long':
        b.write('<path d="M30 45C33 28 67 28 70 45C62 37 38 37 30 45Z" fill="$hair"/>');
      case 'bun':
        b.write('<circle cx="50" cy="21" r="8" fill="$hair"/>');
        b.write('<path d="M30 46C27 21 73 21 70 46C66 36 58 31 50 31S34 36 30 46Z" fill="$hair"/>');
      case 'curly':
        for (final p in const [[34, 36], [42, 28], [50, 26], [58, 28], [66, 36]]) {
          b.write('<circle cx="${p[0]}" cy="${p[1]}" r="8" fill="$hair"/>');
        }
      case 'cap':
        b.write('<path d="M29 43C29 20 71 20 71 43Z" fill="$acc"/><rect x="27" y="40" width="46" height="5" rx="2.5" fill="$acc"/>');
    }
    if (a.glasses) {
      b.write('<circle cx="43" cy="47" r="5.5" fill="none" stroke="$ink" stroke-width="1.8"/><circle cx="57" cy="47" r="5.5" fill="none" stroke="$ink" stroke-width="1.8"/><path d="M48.5 47h3" stroke="$ink" stroke-width="1.8"/>');
    }
  }
  b.write('</svg>');
  return b.toString();
}

/// Avatar rond : illustration choisie, mascotte, ou initiale du nom sur fond [color] si [id] est vide.
class NAvatar extends StatelessWidget {
  final String id;
  final String initial;
  final Color color;
  final double size;
  const NAvatar({super.key, this.id = '', required this.initial, required this.color, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final i = id.startsWith('a') ? int.tryParse(id.substring(1)) : null;
    final Widget inner;
    if (id == 'robot') {
      inner = Container(color: _yellow, padding: EdgeInsets.all(size * 0.12), child: Image.asset('robot.png', fit: BoxFit.contain));
    } else if (i != null && i >= 0 && i < _avatars.length) {
      inner = SvgPicture.string(_avatarSvg(_avatars[i]), width: size, height: size);
    } else {
      inner = Container(color: color, alignment: Alignment.center, child: Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.w600)));
    }
    return SizedBox(width: size, height: size, child: ClipOval(child: inner));
  }
}
