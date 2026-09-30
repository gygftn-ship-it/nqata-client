import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'extras.dart';
import 'map.dart';
import 'onboarding.dart';
import 'tabs.dart';

// La clé "publishable" est faite pour être dans l'app : la sécurité vient des règles (RLS) de la base.
const supabaseUrl = 'https://nmecbbmlvrzeqazapijf.supabase.co';
const supabaseKey = 'sb_publishable_-zL5W-Pf5WMHAZZCONw4_g_RNbjhE5g';
const brandDark = Color(0xFF0B5F50);
const brandLight = Color(0xFF14B8A6);
const rotationSeconds = 45;

String lang = 'fr';
String tr(String fr, String ar) => lang == 'ar' ? ar : fr;

String errText(Object e) {
  final m = e is AuthException ? e.message : e is PostgrestException ? e.message : e.toString();
  if (m.contains('Invalid login credentials')) return tr('E-mail ou mot de passe incorrect', 'بريد أو كلمة سر خاطئة');
  if (m.contains('confirm_email')) return tr('Compte créé : confirmez votre e-mail puis connectez-vous', 'تم إنشاء الحساب: أكّد بريدك ثم سجّل الدخول');
  if (m.contains('rate limit')) return tr('Trop d\'e-mails envoyés, réessayez plus tard', 'رسائل كثيرة، حاول لاحقًا');
  return tr('Erreur : $m', 'خطأ: $m');
}

/// Données de l'utilisateur, lues depuis Supabase.
class Store extends ChangeNotifier {
  bool loggedIn = false;
  String name = '';
  String code = ''; // code client affiché sous le QR
  List<Map<String, dynamic>> wallet = [], shops = [], offers = [], activity = [], notifs = [];
  Map<String, dynamic>? incoming; // notification reçue en direct
  RealtimeChannel? _chan;
  Set<String> favs = {}; // commerces favoris
  bool onboarded = false;
  bool offline = false; // dernière synchronisation échouée : on affiche les données gardées en mémoire
  DateTime? lastSync;
  String? celebrate; // commerce dont une récompense vient d'être débloquée
  int _rewardCount = -1;

  SupabaseClient get sb => Supabase.instance.client;
  String get uid => sb.auth.currentUser!.id;
  String get email => sb.auth.currentUser?.email ?? '';
  int get total => wallet.fold(0, (s, r) => s + (r['points'] as int));
  int get unread => notifs.where((n) => n['read_at'] == null).length;
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
      final p = await sb.from('profiles').select('display_name').eq('id', uid).maybeSingle();
      name = (p?['display_name'] as String?) ?? '';
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
    final r = await Future.wait([
      _q(sb.from('balances').select('points, last_scan_at, shops(id, name, reward_threshold)').eq('client_id', uid)),
      _q(sb.from('shops').select('id, name, category, address, hours, lat, lng, reward_threshold').eq('status', 'active').order('name')),
      _q(sb.from('offers').select('title, shops(name)').order('created_at', ascending: false)),
      _q(sb.from('scans').select('points, created_at, undone_at, shops(name)').eq('client_id', uid).order('created_at', ascending: false).limit(10)),
      _q(sb.from('notifications').select('id, title, body, created_at, read_at').eq('user_id', uid).order('created_at', ascending: false).limit(50)),
    ]);
    wallet = r[0]; shops = r[1]; offers = r[2]; activity = r[3]; notifs = r[4];
    offline = false;
    lastSync = DateTime.now();
    _checkRewards();
    _saveCache();
    notifyListeners();
  }

  Future<void> start() async {
    loggedIn = true;
    notifyListeners();
    _subscribe();
    await _loadCache();
    await refresh();
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
      await p.setString('cache_$uid', jsonEncode({'name': name, 'code': code, 'wallet': wallet, 'shops': shops, 'offers': offers, 'activity': activity, 'notifs': notifs, 'at': DateTime.now().toIso8601String()}));
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
      wallet = _list(m['wallet']); shops = _list(m['shops']); offers = _list(m['offers']); activity = _list(m['activity']); notifs = _list(m['notifs']);
      lastSync = DateTime.tryParse(m['at'] as String? ?? '');
      _checkRewards();
      notifyListeners();
    } catch (_) {}
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

  void finishOnboarding() {
    onboarded = true;
    SharedPreferences.getInstance().then((p) => p.setBool('onboarded', true));
    notifyListeners();
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
            incoming = payload.newRecord;
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
    try { await sb.auth.signOut(); } catch (_) {}
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
  store.onboarded = prefs.getBool('onboarded') ?? false;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  if (Supabase.instance.client.auth.currentSession != null) store.start();
  runApp(const NqataClient());
}

class NqataClient extends StatelessWidget {
  const NqataClient({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66), brightness: b),
        navigationBarTheme: const NavigationBarThemeData(height: 68, indicatorShape: StadiumBorder()),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => MaterialApp(
          title: 'Nqata',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemeMode.system,
          builder: (c, child) => Directionality(textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!),
          home: !store.onboarded ? const OnboardingPage() : store.loggedIn ? const Shell() : const LoginPage(),
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
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight])),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Theme(
                data: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66))),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('NQATA', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4, color: brandDark)),
                    const SizedBox(height: 16),
                    if (signup) _f(name, tr('Prénom ou pseudo', 'الاسم')),
                    _f(email, 'E-mail', type: TextInputType.emailAddress),
                    _f(pass, tr('Mot de passe (6 caractères min.)', 'كلمة السر (6 أحرف على الأقل)'), secret: true),
                    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(signup ? tr('Créer mon compte', 'إنشاء الحساب') : tr('Se connecter', 'دخول')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() { signup = !signup; error = null; }),
                      child: Text(signup ? tr('J\'ai déjà un compte', 'لدي حساب') : tr('Pas de compte ? S\'inscrire', 'ليس لدي حساب؟ سجّل')),
                    ),
                  ]),
                ),
              ),
            ),
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

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() { store.removeListener(_onStore); super.dispose(); }

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
          const Icon(Icons.notifications_active, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('${n['title']} · ${n['body'] ?? ''}')),
        ]),
        action: SnackBarAction(label: tr('Voir', 'عرض'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()))),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [HomeTab(goTo: (i) => setState(() => tab = i)), const MapTab(), const CardsTab(), const OffersTab(), const ProfileTab()];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (store.offline) offlineBanner(),
        NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) { HapticFeedback.selectionClick(); setState(() => tab = i); },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: tr('Accueil', 'الرئيسية')),
          NavigationDestination(icon: const Icon(Icons.map_rounded), label: tr('Carte', 'الخريطة')),
          NavigationDestination(icon: const Icon(Icons.credit_card_rounded), label: tr('Cartes', 'البطاقات')),
          NavigationDestination(icon: const Icon(Icons.local_offer_rounded), label: tr('Offres', 'العروض')),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: tr('Profil', 'الملف')),
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
      const Icon(Icons.wifi_off, size: 16, color: Colors.black87),
      const SizedBox(width: 8),
      Expanded(child: Text('${tr('Hors connexion : dernières données', 'بدون اتصال: آخر البيانات')}$t', style: const TextStyle(color: Colors.black87, fontSize: 12))),
    ]),
  );
}
