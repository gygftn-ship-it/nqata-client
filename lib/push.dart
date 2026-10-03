import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

/// Notifications push (Firebase Cloud Messaging) : elles arrivent même quand l'app est fermée.
/// Quand l'app est ouverte, c'est toujours Supabase Realtime + le bandeau qui s'en occupent.
/// Toutes les erreurs sont absorbées : un souci de push ne doit jamais bloquer l'app.
class Push {
  static bool _ready = false;
  static String? _token;
  static StreamSubscription<String>? _refreshSub;
  static bool _points = true, _rewards = true, _offers = true;

  /// À appeler une fois au démarrage.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      _ready = true;
    } catch (_) {}
  }

  /// À appeler une fois l'utilisateur connecté : demande la permission et enregistre le token dans Supabase.
  static Future<void> register({required bool points, required bool rewards, required bool offers}) async {
    if (!_ready) return;
    _points = points; _rewards = rewards; _offers = offers;
    try {
      await FirebaseMessaging.instance.requestPermission(); // Android 13+ : affiche la demande d'autorisation
      _token = await FirebaseMessaging.instance.getToken();
      await _save();
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _save();
      });
    } catch (_) {}
  }

  /// À appeler quand l'utilisateur change ses préférences (points, récompenses, offres).
  static Future<void> syncPrefs({required bool points, required bool rewards, required bool offers}) async {
    _points = points; _rewards = rewards; _offers = offers;
    await _save();
  }

  /// À appeler AVANT la déconnexion : ce téléphone ne reçoit plus les push de ce compte.
  static Future<void> unregister() async {
    final t = _token;
    _token = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (t == null) return;
    try {
      await Supabase.instance.client.rpc('unregister_device_token', params: {'p_token': t});
    } catch (_) {}
  }

  static Future<void> _save() async {
    final t = _token;
    if (t == null) return;
    try {
      await Supabase.instance.client.rpc('register_device_token', params: {
        'p_token': t,
        'p_n_points': _points,
        'p_n_rewards': _rewards,
        'p_n_offers': _offers,
      });
    } catch (_) {}
  }
}
