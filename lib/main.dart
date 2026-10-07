import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_auth/local_auth.dart';
import 'nicons.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'discover.dart';
import 'extras.dart';
import 'map.dart';
import 'tabs.dart';
import 'home.dart';
import 'nav.dart';
import 'notifs.dart';
import 'push.dart';
import 'policy.dart';
import 'profile.dart';
import 'wallet.dart';

// La clé "publishable" est faite pour être dans l'app : la sécurité vient des règles (RLS) de la base.
const supabaseUrl = 'https://nmecbbmlvrzeqazapijf.supabase.co';
const supabaseKey = 'sb_publishable_-zL5W-Pf5WMHAZZCONw4_g_RNbjhE5g';
const brandDark = Color(0xFF15120B); // noir chaud (encre)
const brandLight = Color(0xFFC58B00); // or (accents, fin des dégradés)
const brandYellow = Color(0xFFFFD60A); // le jaune de la direction artistique
const rotationSeconds = 45;

String lang = 'fr';
String tr(String fr, String ar) => lang == 'ar' ? ar : fr;

String errText(Object e) {
  final m = e is AuthException ? e.message : e is PostgrestException ? e.message : e.toString();
  if (m.contains('Invalid login credentials')) return tr('E-mail ou mot de passe incorrect', 'بريد أو كلمة سر خاطئة');
  if (m.contains('confirm_email')) return tr('Compte créé : confirmez votre e-mail puis connectez-vous', 'تم إنشاء الحساب: أكّد بريدك ثم سجّل الدخول');
  if (m.contains('rate limit')) return tr('Trop d\'e-mails envoyés, réessayez plus tard', 'رسائل كثيرة، حاول لاحقًا');
  if (m.contains('not_visited')) return tr('Visitez ce commerce avant de le noter', 'زر هذا المتجر قبل تقييمه');
  if (m.contains('already_referred')) return tr('Vous avez déjà un parrain', 'لديك راعٍ بالفعل');
  if (m.contains('referral_too_late')) return tr('Trop tard : vous avez déjà visité un commerce', 'فات الأوان: زرت متجرًا بالفعل');
  if (m.contains('code_not_found')) return tr('Code introuvable', 'الرمز غير موجود');
  if (m.contains('own_code')) return tr('Vous ne pouvez pas utiliser votre propre code', 'لا يمكنك استخدام رمزك الخاص');
  if (m.contains('bio_unavailable')) return tr('Aucune empreinte enregistrée sur ce téléphone : ajoutez-en une dans ses réglages', 'لا توجد بصمة مسجلة على هذا الهاتف: أضف واحدة من الإعدادات');
  return tr('Erreur : $m', 'خطأ: $m');
}

/// Données de l'utilisateur, lues depuis Supabase.
class Store extends ChangeNotifier {
  bool loggedIn = false;
  String name = '';
  String code = ''; // code client affiché sous le QR
  List<Map<String, dynamic>> wallet = [], shops = [], offers = [], activity = [], notifs = [];
  bool referredBy = false;
  Map<String, dynamic>? incoming; // notification reçue en direct
  RealtimeChannel? _chan;
  Set<String> favs = {}; // commerces favoris
  Map<String, Map<String, dynamic>> ratings = {}; // note moyenne par commerce
  Map<String, int> myRatings = {}; // mes notes
  // Réglages
  ThemeMode themeMode = ThemeMode.system;
  double textScale = 1.0;
  bool notifsOn = true;
  bool nPoints = true, nRewards = true, nOffers = true;
  int avatarColor = 0;
  String avatarId = ''; // '' = initiale du nom ; sinon 'a0'…'a11' ou 'robot'
  int coverTheme = 0; // thème de l'en-tête du profil
  bool bioEnabled = false; // déverrouillage du portefeuille par empreinte
  LatLng? me; // position de l'utilisateur (jamais envoyée au serveur)
  // Code PIN du portefeuille (haché et salé, jamais stocké en clair)
  String? pinHash, pinSalt;
  bool unlocked = false;
  int pinFails = 0;
  DateTime? pinLockedUntil;
  List<Map<String, dynamic>> txs = []; // transactions : visites et récompenses
  bool offline = false; // dernière synchronisation échouée : on affiche les données gardées en mémoire
  DateTime? lastSync;
  String? celebrate; // commerce dont une récompense vient d'être débloquée
  int _rewardCount = -1;

  SupabaseClient get sb => Supabase.instance.client;
  String get uid => sb.auth.currentUser!.id;
  String get email => sb.auth.currentUser?.email ?? '';
  int get total => wallet.fold(0, (s, r) => s + (r['points'] as int));
  bool get hasPin => pinHash != null;
  int get unread => notifsShown.where((n) => n['read_at'] == null).length;

  // Préférences de notification : on masque les catégories désactivées
  bool notifAllowed(Map<String, dynamic> n) {
    final b = '${n['body'] ?? ''}';
    if (b.startsWith('+')) return nPoints;
    if (b.contains('Récompense')) return nRewards;
    if (b.toLowerCase().contains('offre')) return nOffers;
    return notifsOn;
  }

  List<Map<String, dynamic>> get notifsShown => notifs.where(notifAllowed).toList();
  List<String> get rewardsReady => [
        for (final r in wallet)
          if ((r['points'] as int) >= (((r['shops'] as Map?)?['reward_threshold'] as int?) ?? 100)) '${(r['shops'] as Map?)?['name'] ?? ''}'
      ];

  Future<List<Map<String, dynamic>>> _q(Future<dynamic> f) async {
    try {
      return List<Map<String, dynamic>>.from(await f);
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    try {
      final p = await sb.from('profiles').select('display_name, referred_by').eq('id', uid).maybeSingle();
      name = (p?['display_name'] as String?) ?? '';
      referredBy = p?['referred_by'] != null;
    } catch (_) {
      offline = true;
      notifyListeners();
      return;
    }
    try {
      final c = await sb.from('profiles').select('client_code').eq('id', uid).maybeSingle();
      code = (c?['client_code'] as String?) ?? '';
    } catch (_) {}
    favs = (await _q(sb.from('favorites').select('shop_id').eq('client_id', uid))).map((r) => '${r['shop_id']}').toSet();
    ratings = {for (final r in await _q(sb.from('shop_ratings').select('shop_id, avg_rating, reviews_count'))) '${r['shop_id']}': r};
    myRatings = {for (final r in await _q(sb.from('shop_reviews').select('shop_id, rating').eq('client_id', uid))) '${r['shop_id']}': r['rating'] as int};
    txs = await _loadTxs();
    final r = await Future.wait([
      _q(sb.from('balances').select('points, last_scan_at, shops(id, name, reward_threshold)').eq('client_id', uid)),
      _q(sb.from('shops').select('id, name, category, address, hours, lat, lng, reward_threshold, description, logo_url, cover_url, cover_color').eq('status', 'active').order('name')),
      _q(sb.from('offers').select('title, shop_id, shops(name)').order('created_at', ascending: false)),
      _q(sb.from('scans').select('points, created_at, undone_at, shops(name)').eq('client_id', uid).order('created_at', ascending: false).limit(10)),
      _q(sb.from('notifications').select('id, title, body, created_at, read_at').eq('user_id', uid).order('created_at', ascending: false).limit(50)),
    ]);
    wallet = r[0]; shops = r[1]; offers = r[2]; activity = r[3]; notifs = r[4];
    offline = false;
    lastSync = DateTime.now();
    _checkRewards();
    _saveCache();
    try { await sb.rpc('expire_my_points'); } catch (_) {}
    notifyListeners();
  }

  Future<void> start() async {
    loggedIn = true;
    notifyListeners();
    _subscribe();
    await _loadCache();
    await refresh();
    Push.register(points: nPoints, rewards: nRewards, offers: nOffers); // notifications push (app fermée)
  }

  // Confettis quand le nombre de récompenses disponibles augmente
  void _checkRewards() {
    var n = 0;
    String? who;
    for (final r in wallet) {
      final shop = r['shops'] as Map?;
      final c = (r['points'] as int) ~/ (((shop?['reward_threshold']) as int?) ?? 100);
      n += c;
      if (c > 0) who = '${shop?['name'] ?? ''}';
    }
    if (_rewardCount >= 0 && n > _rewardCount) celebrate = who ?? '';
    _rewardCount = n;
  }

  // Mode hors connexion : dernières données gardées sur le téléphone
  Future<void> _saveCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('cache_$uid', jsonEncode({'name': name, 'code': code, 'wallet': wallet, 'shops': shops, 'offers': offers, 'activity': activity, 'notifs': notifs, 'txs': txs, 'at': DateTime.now().toIso8601String()}));
    } catch (_) {}
  }

  List<Map<String, dynamic>> _list(dynamic v) => [for (final e in (v as List? ?? [])) Map<String, dynamic>.from(e as Map)];

  Future<void> _loadCache() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('cache_$uid');
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      name = m['name'] as String? ?? '';
      code = m['code'] as String? ?? '';
      wallet = _list(m['wallet']); shops = _list(m['shops']); offers = _list(m['offers']); activity = _list(m['activity']); notifs = _list(m['notifs']); txs = _list(m['txs']);
      lastSync = DateTime.tryParse(m['at'] as String? ?? '');
      _checkRewards();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadTxs() async {
    final sc = await _q(sb.from('scans').select('points, created_at, undone_at, shop_id, shops(name)').eq('client_id', uid).order('created_at', ascending: false).limit(100));
    final rd = await _q(sb.from('redemptions').select('points_cost, created_at, shop_id, shops(name)').eq('client_id', uid).order('created_at', ascending: false).limit(100));
    final all = <Map<String, dynamic>>[
      for (final s in sc) {'type': 'visit', 'shop_id': s['shop_id'], 'shop': (s['shops'] as Map?)?['name'], 'amount': s['points'], 'at': s['created_at'], 'undone': s['undone_at'] != null},
      for (final r in rd) {'type': 'reward', 'shop_id': r['shop_id'], 'shop': (r['shops'] as Map?)?['name'], 'amount': -(r['points_cost'] as int), 'at': r['created_at'], 'undone': false},
    ];
    all.sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
    return all;
  }

  // ----- Code PIN -----
  String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();
  bool checkPin(String pin) => pinHash != null && _hash(pinSalt!, pin) == pinHash;

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    pinSalt = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    pinHash = _hash(pinSalt!, pin);
    unlocked = true;
    pinFails = 0;
    final p = await SharedPreferences.getInstance();
    await p.setString('pin_salt', pinSalt!);
    await p.setString('pin_hash', pinHash!);
    notifyListeners();
  }

  Future<void> removePin() async {
    pinHash = null;
    pinSalt = null;
    unlocked = false;
    final p = await SharedPreferences.getInstance();
    await p.remove('pin_salt');
    await p.remove('pin_hash');
    await p.setBool('bio', false);
    bioEnabled = false;
    notifyListeners();
  }

  bool unlock(String pin) {
    final until = pinLockedUntil;
    if (until != null && DateTime.now().isBefore(until)) return false;
    if (checkPin(pin)) {
      unlocked = true;
      pinFails = 0;
      pinLockedUntil = null;
      notifyListeners();
      return true;
    }
    if (++pinFails >= 5) {
      pinLockedUntil = DateTime.now().add(const Duration(seconds: 30));
      pinFails = 0;
    }
    notifyListeners();
    return false;
  }

  void lock() {
    if (hasPin && unlocked) {
      unlocked = false;
      notifyListeners();
    }
  }

  Future<void> _save(String k, Object v) async {
    final p = await SharedPreferences.getInstance();
    if (v is bool) {
      await p.setBool(k, v);
    } else if (v is int) {
      await p.setInt(k, v);
    } else if (v is double) {
      await p.setDouble(k, v);
    } else if (v is String) {
      await p.setString(k, v);
    }
  }

  void setThemeMode(ThemeMode m) { themeMode = m; _save('theme', m.name); notifyListeners(); }
  void setTextScale(double s) { textScale = s; _save('tscale', s); notifyListeners(); }
  void setAvatarColor(int i) { avatarColor = i; _save('avatar', i); notifyListeners(); }
  void setAvatarId(String e) { avatarId = e; _save('avatar_id', e); notifyListeners(); }
  void setCoverTheme(int i) { coverTheme = i; _save('cover', i); notifyListeners(); }
  Future<void> setNotifsOn(bool v) async {
    notifsOn = v;
    await _save('notifs_on', v);
    try {
      v ? await Push.register(points: nPoints, rewards: nRewards, offers: nOffers) : await Push.unregister();
    } catch (_) {}
    notifyListeners();
  }

  void setNotifPref(String k, bool v) {
    if (k == 'points') nPoints = v;
    if (k == 'rewards') nRewards = v;
    if (k == 'offers') nOffers = v;
    _save('n_$k', v);
    Push.syncPrefs(points: nPoints, rewards: nRewards, offers: nOffers);
    notifyListeners();
  }

  Future<void> changePassword(String p) async {
    await sb.auth.updateUser(UserAttributes(password: p));
  }

  Future<void> signOutEverywhere() async {
    await Push.unregister();
    try { await sb.auth.signOut(scope: SignOutScope.global); } catch (_) {}
    await signOut();
  }

  // ----- Empreinte digitale -----
  final _localAuth = LocalAuthentication();

  Future<bool> bioAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics && (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _bioPrompt() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: tr('Déverrouillez votre portefeuille Nqata', 'افتح محفظة نقطة'),
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockBio() async {
    if (!hasPin || !bioEnabled) return false;
    final ok = await _bioPrompt();
    if (ok) {
      unlocked = true;
      pinFails = 0;
      pinLockedUntil = null;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setBio(bool v) async {
    if (v) {
      if (!await bioAvailable()) throw 'bio_unavailable';
      if (!await _bioPrompt()) return;
    }
    bioEnabled = v;
    _save('bio', v);
    notifyListeners();
  }

  // ----- Position et distances -----
  Future<void> locate({bool ask = false}) async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      me = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (_) {}
  }

  double? km(Map<String, dynamic> s) {
    final lat = (s['lat'] as num?)?.toDouble(), lng = (s['lng'] as num?)?.toDouble();
    if (me == null || lat == null || lng == null) return null;
    return const Distance().distance(me!, LatLng(lat, lng)) / 1000;
  }

  Future<void> rate(String shopId, int n, {String? comment}) async {
    await sb.rpc('rate_shop', params: {'p_shop': shopId, 'p_rating': n, if (comment != null) 'p_comment': comment});
    myRatings[shopId] = n;
    notifyListeners();
    await refresh();
  }

  Future<List<Map<String, dynamic>>> shopReviews(String shopId) =>
      _q(sb.from('shop_reviews_public').select('id, display_name, rating, comment, created_at, reply, replied_at').eq('shop_id', shopId).order('created_at', ascending: false));

  // ----- Parrainage -----
  Future<String> applyReferral(String code) async => await sb.rpc('apply_referral', params: {'p_code': code}) as String;
  Future<Map<String, dynamic>> referralStats() async {
    try {
      return Map<String, dynamic>.from(await sb.rpc('referral_stats') as Map);
    } catch (_) {
      return {'friends': 0, 'paid': 0};
    }
  }

  Future<void> toggleFav(String id) async {
    final was = favs.contains(id);
    was ? favs.remove(id) : favs.add(id);
    notifyListeners();
    try {
      if (was) {
        await sb.from('favorites').delete().eq('client_id', uid).eq('shop_id', id);
      } else {
        await sb.from('favorites').insert({'client_id': uid, 'shop_id': id});
      }
    } catch (_) {
      was ? favs.add(id) : favs.remove(id);
      notifyListeners();
    }
  }

  // Notifications reçues en direct (Supabase Realtime)
  void _subscribe() {
    if (_chan != null) return;
    _chan = sb
        .channel('notifs-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) {
            if (notifAllowed(payload.newRecord)) incoming = payload.newRecord;
            refresh();
          },
        )
        .subscribe();
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    try {
      await sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', uid).isFilter('read_at', null);
    } catch (_) {}
    await refresh();
  }

  Future<void> signIn(String e, String p) async {
    await sb.auth.signInWithPassword(email: e, password: p);
    await start();
  }

  Future<void> signUp(String e, String p, String n) async {
    final r = await sb.auth.signUp(email: e, password: p, data: {'display_name': n.isEmpty ? 'Client' : n});
    if (r.session == null) throw 'confirm_email';
    await start();
  }

  Future<void> signOut() async {
    await Push.unregister(); // avant la déconnexion, pour ne plus recevoir les push de ce compte
    try { await sb.auth.signOut(); } catch (_) {}
    await removePin();
    if (_chan != null) { sb.removeChannel(_chan!); _chan = null; }
    loggedIn = false; name = ''; code = ''; wallet = []; shops = []; offers = []; activity = []; notifs = []; favs = {}; incoming = null; celebrate = null; offline = false; _rewardCount = -1;
    notifyListeners();
  }

  Future<void> rename(String n) async {
    await sb.from('profiles').update({'display_name': n}).eq('id', uid);
    name = n;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await sb.rpc('delete_my_account');
    await signOut();
  }

  void setLang(String l) {
    lang = l;
    SharedPreferences.getInstance().then((p) => p.setString('lang', l));
    notifyListeners();
  }
}

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  lang = prefs.getString('lang') ?? 'fr';
  store.pinHash = prefs.getString('pin_hash');
  store.pinSalt = prefs.getString('pin_salt');
  store.themeMode = ThemeMode.values.firstWhere((m) => m.name == prefs.getString('theme'), orElse: () => ThemeMode.system);
  store.textScale = prefs.getDouble('tscale') ?? 1.0;
  store.notifsOn = prefs.getBool('notifs_on') ?? true;
  store.nPoints = prefs.getBool('n_points') ?? true;
  store.nRewards = prefs.getBool('n_rewards') ?? true;
  store.nOffers = prefs.getBool('n_offers') ?? true;
  store.avatarColor = prefs.getInt('avatar') ?? 0;
  store.avatarId = prefs.getString('avatar_id') ?? '';
  store.coverTheme = prefs.getInt('cover') ?? 0;
  store.bioEnabled = prefs.getBool('bio') ?? false;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  await Push.init();
  if (Supabase.instance.client.auth.currentSession != null) store.start();
  runApp(const NqataClient());
}

class NqataClient extends StatelessWidget {
  const NqataClient({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => MaterialApp(
          title: 'Nqata',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          scrollBehavior: const BouncyScroll(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(store.textScale)), child: Directionality(textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!)),
          home: store.loggedIn ? const Shell() : const LoginPage(),
        ),
      );
}

// ---------- Connexion / inscription ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  bool signup = false, busy = false;
  String? error;

  @override
  void dispose() { name.dispose(); email.dispose(); pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      final e = email.text.trim();
      signup ? await store.signUp(e, pass.text, name.text.trim()) : await store.signIn(e, pass.text);
    } catch (err) {
      if (mounted) setState(() => error = errText(err));
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _f(TextEditingController c, String l, {bool secret = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, obscureText: secret, keyboardType: type, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: brandYellow,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Stack(children: [
              SizedBox(height: 270, width: double.infinity, child: Image.asset('mascot_hero.jpg', fit: BoxFit.cover, alignment: const Alignment(0.3, -0.1))),
              Padding(
                padding: const EdgeInsets.only(top: 236),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 280),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Image.asset('coin.png', width: 36, height: 36),
                      const SizedBox(width: 10),
                      const Text('NQATA', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    ]),
                    const SizedBox(height: 16),
                    if (signup) _f(name, tr('Prénom ou pseudo', 'الاسم')),
                    _f(email, 'E-mail', type: TextInputType.emailAddress),
                    _f(pass, tr('Mot de passe (6 caractères min.)', 'كلمة السر (6 أحرف على الأقل)'), secret: true),
                    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(signup ? tr('Créer mon compte', 'إنشاء الحساب') : tr('Se connecter', 'دخول')),
                      ),
                    ),
                    TextButton(onPressed: () => setState(() { signup = !signup; error = null; }), child: Text(signup ? tr('J\'ai déjà un compte', 'لدي حساب') : tr('Pas de compte ? S\'inscrire', 'ليس لدي حساب؟ سجّل'))),
                    TextButton(onPressed: () => Navigator.push(context, smoothRoute(const PolicyPage())), child: Text(tr('Politique de confidentialité', 'سياسة الخصوصية'), style: const TextStyle(fontSize: 12))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ---------- Coque : 5 onglets ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); store.removeListener(_onStore); super.dispose(); }

  // Le portefeuille se reverrouille quand l'app passe en arrière-plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {}  // le portefeuille ne se reverrouille plus en arrière-plan : une seule demande par ouverture de l'app

  // Bandeau affiché quand une notification arrive pendant que l'app est ouverte
  void _onStore() {
    if (mounted) setState(() {});
    final who = store.celebrate;
    if (who != null && mounted) {
      store.celebrate = null;
      showConfetti(context, who);
    }
    final n = store.incoming;
    if (n == null || !mounted) return;
    store.incoming = null;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          const NIcon('bell', color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('${n['title']} · ${n['body'] ?? ''}')),
        ]),
        action: SnackBarAction(label: tr('Voir', 'عرض'), onPressed: () => Navigator.push(context, smoothRoute(const NotificationsPage()))),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(goTo: (i) => setState(() => tab = i)), const MapTab(), const WalletTab(), const DiscoverTab(), const ProfileScreen()];
    return Scaffold(
      body: SafeArea(
        top: tab != 4, // l'onglet Profil dessine lui-même son en-tête sous la barre d'état
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child)),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (store.offline) offlineBanner(),
        FloatingNav(
          index: tab,
          onTap: (i) { HapticFeedback.selectionClick(); setState(() => tab = i); },
          items: [
            ('home', 'home', tr('Accueil', 'الرئيسية')),
            ('pin', 'pin', tr('Carte', 'الخريطة')),
            ('wallet', 'wallet', tr('Portefeuille', 'المحفظة')),
            ('tag', 'tag', tr('Offres', 'العروض')),
            ('user', 'user', tr('Profil', 'الملف')),
          ],
        ),
      ]),
    );
  }
}

Widget offlineBanner() {
  final d = store.lastSync?.toLocal();
  final t = d == null ? '' : ' · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return Container(
    width: double.infinity,
    color: Colors.amber.shade700,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      const NIcon('wifi_off', size: 16, color: Colors.black87),
      const SizedBox(width: 8),
      Expanded(child: Text('${tr('Hors connexion : dernières données', 'بدون اتصال: آخر البيانات')}$t', style: const TextStyle(color: Colors.black87, fontSize: 12))),
    ]),
  );
}

/// Transition de page fluide : fondu + léger glissement vers le haut.
PageRouteBuilder<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c), child: child));
      },
    );

/// Défilement élastique sur tous les écrans.
class BouncyScroll extends MaterialScrollBehavior {
  const BouncyScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  const ink = Color(0xFF15120B);
  final cs = ColorScheme.fromSeed(seedColor: brandYellow, brightness: b).copyWith(
    primary: brandYellow,
    onPrimary: Colors.black,
    secondaryContainer: brandYellow,
    onSecondaryContainer: Colors.black,
    surface: light ? Colors.white : const Color(0xFF0F0E0B),
  );
  final link = light ? ink : brandYellow;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(backgroundColor: cs.surface, surfaceTintColor: Colors.transparent, foregroundColor: light ? ink : Colors.white),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: brandYellow, foregroundColor: Colors.black, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: link, shape: const StadiumBorder(), side: BorderSide(color: link, width: 1.5))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: link, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    chipTheme: const ChipThemeData(shape: StadiumBorder(), showCheckmark: false),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: light ? ink : brandYellow),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: brandYellow, foregroundColor: Colors.black),
  );
}
