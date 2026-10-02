import 'package:flutter/material.dart';
import 'nicons.dart';
import 'main.dart';

/// Barre de navigation flottante : l'onglet actif s'agrandit et affiche son nom.
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(String, String, String)> items; // (icône, icône active, nom)
  const FloatingNav({super.key, required this.index, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 2 : 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(horizontal: i == index ? 12 : 8, vertical: 8),
                      decoration: BoxDecoration(color: i == index ? brandYellow : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedScale(
                            scale: i == index ? 1.12 : 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            child: NIcon(items[i].$1, color: i == index ? Colors.black87 : Colors.grey, accent: i == index ? Colors.white : Colors.grey.shade400, size: 26),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: i == index
                                ? Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Text(items[i].$3, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)))
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
