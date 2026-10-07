import 'package:flutter/material.dart';
import 'main.dart';

// Couleurs communes (mêmes valeurs que l'écran Profil), réutilisées par le portefeuille, le bandeau et le tutoriel.
bool nDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color nInk(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color nMuted(BuildContext c) => nInk(c).withOpacity(0.62);
Color nGold(BuildContext c) => nDark(c) ? brandYellow : brandLight;
Color nTint(BuildContext c) => nDark(c) ? const Color(0xFF1B1912) : const Color(0xFFF6F3EA);
