import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'extras.dart';
import 'main.dart';
import 'shop.dart';
import 'tabs.dart';

// ======================= Code PIN =======================

/// Clavier numérique avec points de saisie, vibrations et secousse en cas d'erreur.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<String?> Function(String pin) onComplete; // renvoie un message d'erreur, ou null si OK
  const PinPad({super.key, required this.title, this.subtitle, required this.onComplete});
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String pin = '';
  String? error;
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void dispose() { shake.dispose(); super.dispose(); }

  Future<void> _tap(String d) async {
    if (pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() { pin += d; error = null; });
    if (pin.length == 4) {
      final err = await widget.onComplete(pin);
      if (!mounted) return;
      if (err != null) {
        HapticFeedback.heavyImpact();
        shake.forward(from: 0);
        setState(() { pin = ''; error = err; });
      }
    }
  }

  void _back() { if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1)); }

  Widget _key(String label, VoidCallback? onTap) {
    if (label.isEmpty) return const SizedBox(width: 74, height: 74);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          child: label == '⌫' ? const Icon(Icons.backspace_outlined) : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, size: 44, color: brandLight),
            const SizedBox(height: 12),
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            if (widget.subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.subtitle!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: shake,
              builder: (_, child) => Transform.translate(offset: Offset(sin(shake.value * pi * 6) * 12 * (1 - shake.value), 0), child: child),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? brandLight : Colors.transparent, border: Border.all(color: brandLight, width: 2)),
                  ),
              ]),
            ),
            SizedBox(height: 40, child: Center(child: Text(error ?? '', style: const TextStyle(color: Colors.red)))),
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '⌫']])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) _key(k, k == '⌫' ? _back : () => _tap(k))]),
          ]),
        ),
      );
}

class _PinScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? Function(String)? validate;
  const _PinScreen({required this.title, this.subtitle, this.validate});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: PinPad(
            title: title,
            subtitle: subtitle,
            onComplete: (pin) async {
              final err = validate?.call(pin);
              if (err == null) Navigator.of(context).pop(pin);
              return err;
            },
          ),
        ),
      );
}

/// Demande un PIN en plein écran. Renvoie le PIN saisi, ou null si annulé.
Future<String?> askPin(BuildContext context, String title, {String? subtitle, String? Function(String)? validate}) =>
    Navigator.push<String>(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PinScreen(title: title, subtitle: subtitle, validate: validate)));

Future<void> setupPin(BuildContext context) async {
  final a = await askPin(context, tr('Choisissez un code PIN', 'اختر رمز PIN'), subtitle: tr('4 chiffres pour protéger votre portefeuille', '4 أرقام لحماية محفظتك'));
  if (a == null || !context.mounted) return;
  final b = await askPin(context, tr('Confirmez le code PIN', 'أكّد رمز PIN'), validate: (p) => p == a ? null : tr('Les codes ne correspondent pas', 'الرمزان غير متطابقين'));
  if (b == null || !context.mounted) return;
  await store.setPin(a);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Code PIN activé', 'تم تفعيل رمز PIN'))));
}

/// Ligne « Code PIN » du profil : définir, modifier ou supprimer.
class PinSettingsTile extends StatelessWidget {
  const PinSettingsTile({super.key});

  Future<bool> _verify(BuildContext context) async =>
      await askPin(context, tr('Code PIN actuel', 'رمز PIN الحالي'), validate: (p) => store.checkPin(p) ? null : tr('Code incorrect', 'رمز خاطئ')) != null;

  void _menu(BuildContext context) {
    if (!store.hasPin) { setupPin(context); return; }
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(tr('Modifier le code PIN', 'تغيير رمز PIN')),
            onTap: () async {
              Navigator.pop(sheet);
              if (await _verify(context) && context.mounted) await setupPin(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.red),
            title: Text(tr('Supprimer le code PIN', 'حذف رمز PIN'), style: const TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(sheet);
              if (await _verify(context)) await store.removePin();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(tr('Code PIN du portefeuille', 'رمز PIN للمحفظة')),
          subtitle: Text(store.hasPin ? tr('Activé', 'مفعّل') : tr('Non défini', 'غير محدد')),
          onTap: () => _menu(context),
        ),
      );
}

class LockView extends StatelessWidget {
  const LockView({super.key});
  @override
  Widget build(BuildContext context) => PinPad(
        title: tr('Portefeuille verrouillé', 'المحفظة مقفلة'),
        subtitle: tr('Entrez votre code PIN', 'أدخل رمز PIN'),
        onComplete: (pin) async {
          final until = store.pinLockedUntil;
          if (until != null && DateTime.now().isBefore(until)) {
            return tr('Trop d\'essais : réessayez dans ${until.difference(DateTime.now()).inSeconds + 1} s', 'محاولات كثيرة: أعد المحاولة بعد ${until.difference(DateTime.now()).inSeconds + 1} ثانية');
          }
          if (store.unlock(pin)) return null;
          return store.pinLockedUntil != null ? tr('Trop d\'essais : réessayez dans 30 s', 'محاولات كثيرة: أعد المحاولة بعد 30 ثانية') : tr('Code incorrect', 'رمز خاطئ');
        },
      );
}

// ======================= Effets visuels =======================

/// Les cartes s'inclinent légèrement sous le doigt (effet 3D).
class TiltCard extends StatefulWidget {
  final Widget child;
  const TiltCard({super.key, required this.child});
  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset tilt = Offset.zero;
  bool active = false;

  void _move(PointerEvent e) {
    final size = context.size;
    if (size == null) return;
    setState(() {
      active = true;
      tilt = Offset(((e.localPosition.dx / size.width) - 0.5).clamp(-0.5, 0.5).toDouble() * 0.5, ((e.localPosition.dy / size.height) - 0.5).clamp(-0.5, 0.5).toDouble() * 0.5);
    });
  }

  void _end(PointerEvent e) => setState(() { active = false; tilt = Offset.zero; });

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _move,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: tilt),
          duration: active ? Duration.zero : const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: widget.child,
          builder: (_, t, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateX(-t.dy)..rotateY(t.dx),
            child: child,
          ),
        ),
      );
}

/// Reflet lumineux qui traverse la carte.
class Sheen extends StatefulWidget {
  const Sheen({super.key});
  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-2.5 + 5 * c.value, -1),
                end: Alignment(-1.5 + 5 * c.value, 1),
                colors: [Colors.transparent, Colors.white.withOpacity(0.16), Colors.transparent],
              ),
            ),
          ),
        ),
      );
}

// ======================= Portefeuille =======================
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final pc = PageController(viewportFraction: 0.86);
  int page = 0;
  String filter = 'all';

  @override
  void dispose() { pc.dispose(); super.dispose(); }

  static String _day(DateTime d) {
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    return diff == 0 ? tr('Aujourd\'hui', 'اليوم') : diff == 1 ? tr('Hier', 'أمس') : '${d.day}/${d.month}/${d.year}';
  }

  Widget _circle(double s) => Container(width: s, height: s, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10));

  Widget _shell(List<Color> colors, Widget child) => AspectRatio(
        aspectRatio: 1.586,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            boxShadow: [BoxShadow(color: colors.last.withOpacity(0.45), blurRadius: 28, offset: const Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              Positioned(right: -40, top: -40, child: _circle(160)),
              Positioned(left: -50, bottom: -60, child: _circle(180)),
              child,
              const Positioned.fill(child: Sheen()),
            ]),
          ),
        ),
      );

  static const _white = TextStyle(color: Colors.white);
  static const _dim = TextStyle(color: Colors.white70);

  // Carte Nqata permanente : toujours présente, même sans aucune visite
  Widget _member() {
    final colors = [const Color(0xFF06201C), brandDark, brandLight];
    final front = _shell(
      colors,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('NQATA', style: _white.copyWith(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4)),
            const Spacer(),
            const Icon(Icons.contactless_rounded, color: Colors.white),
          ]),
          const Spacer(),
          Text(store.name.isEmpty ? '…' : store.name.toUpperCase(), style: _white.copyWith(fontSize: 18, letterSpacing: 3), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(store.code.isEmpty ? '······' : store.code, style: _dim.copyWith(letterSpacing: 4, fontFamily: 'monospace', fontSize: 16)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedCount(store.total, style: _white.copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(' pts', style: _dim),
            ]),
          ]),
        ]),
      ),
    );
    final back = _shell(
      colors,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(tr('Carte membre Nqata', 'بطاقة عضو نقطة'), style: _white.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('${store.wallet.length} ${tr('commerce(s) • ', 'متجر • ')}${store.rewardsReady.length} ${tr('récompense(s) prête(s)', 'مكافأة جاهزة')}', style: _white),
          const SizedBox(height: 6),
          Text('${tr('Mon code', 'رمزي')} : ${store.code}', style: _dim),
          const SizedBox(height: 6),
          Text(tr('Montrez le QR de l\'accueil pour gagner des points', 'اعرض رمز الرئيسية لكسب النقاط'), style: _dim.copyWith(fontSize: 12)),
        ]),
      ),
    );
    return TiltCard(child: FlipCard(front: front, back: back));
  }

  Widget _shopCard(Map<String, dynamic> row, int idx) {
    final info = (row['shops'] as Map?) ?? {};
    Map<String, dynamic>? shop;
    for (final s in store.shops) {
      if (s['id'] == info['id']) shop = s;
    }
    final pts = row['points'] as int;
    final thr = (info['reward_threshold'] as int?) ?? 100;
    final base = hexColor(shop?['cover_color'] as String?) ?? cardGrads[idx % 4][0];
    final colors = [Color.lerp(base, Colors.black, 0.45)!, base, Color.lerp(base, Colors.white, 0.3)!];
    final front = _shell(
      colors,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (shop != null) ...[ShopLogo(shop: shop, size: 38), const SizedBox(width: 10)],
            Expanded(child: Text('${info['name'] ?? ''}', style: _white.copyWith(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.contactless_rounded, color: Colors.white),
          ]),
          if (pts >= thr)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
              child: Text('🎁 ${pts ~/ thr} ${tr('récompense(s)', 'مكافأة')}', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          AnimatedCount(pts, style: _white.copyWith(fontSize: 40, fontWeight: FontWeight.bold)),
          Text(tr('points', 'نقطة'), style: _dim),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (pts % thr) / thr, minHeight: 7, backgroundColor: Colors.white24, color: Colors.white)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('•••• ${store.uid.substring(0, 4).toUpperCase()}', style: _dim.copyWith(letterSpacing: 2)),
            Text('${pts % thr} / $thr', style: _dim),
          ]),
        ]),
      ),
    );
    final back = _shell(
      colors,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${info['name'] ?? ''}', style: _white.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(tr('Prochaine récompense dans ${thr - pts % thr} points', 'المكافأة التالية بعد ${thr - pts % thr} نقطة'), style: _white),
          const SizedBox(height: 4),
          Text('${tr('Dernière visite', 'آخر زيارة')} : ${fmtDate(row['last_scan_at'] as String?)}', style: _dim),
          if (shop != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(shop: shop!))),
                child: Text('${tr('Voir le commerce', 'عرض المتجر')} →', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
    return TiltCard(child: FlipCard(front: front, back: back));
  }

  Widget _pinBanner() => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.shield_outlined, color: brandLight),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('Protégez votre portefeuille avec un code PIN', 'احمِ محفظتك برمز PIN'))),
          TextButton(onPressed: () => setupPin(context), child: Text(tr('Activer', 'تفعيل'))),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          if (store.hasPin && !store.unlocked) return const LockView();
          final theme = Theme.of(context);
          final rows = [...store.wallet]..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
          if (page > rows.length) page = 0;
          final shopId = page == 0 ? null : (rows[page - 1]['shops'] as Map?)?['id'];
          final txs = store.txs.where((t) {
            if (shopId != null && t['shop_id'] != shopId) return false;
            return filter == 'all' || (filter == 'gain' ? t['type'] == 'visit' : t['type'] == 'reward');
          }).take(30).toList();
          DateTime at(int i) => DateTime.parse('${txs[i]['at']}').toLocal();
          return Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [brandDark.withOpacity(0.35), theme.colorScheme.surface], stops: const [0, 0.55])),
            child: RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(top: 16, bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Mon portefeuille', 'محفظتي'), style: theme.textTheme.bodyMedium),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          AnimatedCount(store.total, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                          Padding(padding: const EdgeInsets.only(bottom: 6, left: 6), child: Text(tr('points', 'نقطة'))),
                        ]),
                      ]),
                    ),
                    if (store.hasPin) IconButton(icon: const Icon(Icons.lock_outline), tooltip: tr('Verrouiller', 'قفل'), onPressed: store.lock),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: pc,
                    itemCount: rows.length + 1,
                    onPageChanged: (i) { HapticFeedback.selectionClick(); setState(() => page = i); },
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                      child: Center(child: i == 0 ? _member() : _shopCard(rows[i - 1], i)),
                    ),
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < rows.length + 1; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.all(3),
                      width: page == i ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: page == i ? brandLight : Colors.grey.shade400, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text(tr('Touchez une carte pour la retourner', 'المس البطاقة لقلبها'), style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!store.hasPin) _pinBanner(),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text(page == 0 ? tr('Transactions', 'المعاملات') : '${tr('Transactions', 'المعاملات')} · ${(rows[page - 1]['shops'] as Map?)?['name'] ?? ''}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())), child: Text(tr('Voir tout', 'عرض الكل'))),
                    ]),
                    Wrap(spacing: 8, children: [
                      for (final f in const [('all', 'Tout', 'الكل'), ('gain', 'Gains', 'الأرباح'), ('reward', 'Récompenses', 'المكافآت')])
                        ChoiceChip(label: Text(tr(f.$2, f.$3)), selected: filter == f.$1, onSelected: (_) => setState(() => filter = f.$1)),
                    ]),
                    if (txs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Center(child: Text(tr('Aucune transaction pour le moment', 'لا توجد معاملات حاليًا')))),
                    for (var i = 0; i < txs.length; i++) ...[
                      if (i == 0 || _day(at(i)) != _day(at(i - 1)))
                        Padding(padding: const EdgeInsets.only(top: 14, bottom: 2), child: Text(_day(at(i)), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
                      FadeSlideIn(
                        index: i,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: txs[i]['type'] == 'reward' ? Colors.amber : (txs[i]['undone'] == true ? Colors.grey : Colors.green),
                            child: Icon(txs[i]['type'] == 'reward' ? Icons.card_giftcard_rounded : (txs[i]['undone'] == true ? Icons.block : Icons.add), color: Colors.white),
                          ),
                          title: Text('${txs[i]['shop'] ?? ''}'),
                          subtitle: Text(txs[i]['type'] == 'reward' ? tr('Récompense utilisée', 'مكافأة مستخدمة') : (txs[i]['undone'] == true ? tr('Annulé', 'ملغى') : tr('Visite', 'زيارة'))),
                          trailing: Text(
                            '${(txs[i]['amount'] as int) > 0 ? '+' : ''}${txs[i]['amount']}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txs[i]['type'] == 'reward' ? Colors.orange : (txs[i]['undone'] == true ? Colors.grey : Colors.green), decoration: txs[i]['undone'] == true ? TextDecoration.lineThrough : null),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}
