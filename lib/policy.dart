import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';

// Politique de confidentialité (version provisoire : à faire valider par un juriste avant la publication).
const _sections = [
  (r'''Qui sommes-nous ?''', r'''من نحن؟''', r'''Nqata est un service de cartes de fidélité qui relie des clients et des commerces partenaires. Cette politique explique quelles données nous traitons, pourquoi, et quels sont vos droits.''', r'''نقطة خدمة بطاقات ولاء تربط الزبائن بالمتاجر الشريكة. توضح هذه السياسة البيانات التي نعالجها ولماذا وما هي حقوقك.'''),
  (r'''Les données que nous collectons''', r'''البيانات التي نجمعها''', r'''• Votre compte : prénom ou pseudo, adresse e-mail et mot de passe (conservé sous forme chiffrée, jamais lisible).
• Votre code client et vos QR temporaires.
• Votre activité : visites, points, récompenses utilisées, commerces favoris et notes données.
• Les notifications reçues et vos préférences.
• Un identifiant technique de votre téléphone, pour pouvoir vous envoyer des notifications.
• Vos réglages (langue, thème, code PIN, empreinte) : ils restent sur votre téléphone.''', r'''• حسابك: الاسم أو اللقب والبريد الإلكتروني وكلمة السر (محفوظة مشفرة ولا يمكن قراءتها).
• رمز الزبون ورموز QR المؤقتة.
• نشاطك: الزيارات والنقاط والمكافآت المستخدمة والمتاجر المفضلة والتقييمات.
• الإشعارات المستلمة وتفضيلاتك.
• معرّف تقني لهاتفك لإرسال الإشعارات إليك.
• إعداداتك (اللغة والسمة ورمز PIN والبصمة): تبقى على هاتفك.'''),
  (r'''Pourquoi nous utilisons ces données''', r'''لماذا نستخدم هذه البيانات''', r'''• Faire fonctionner votre carte de fidélité : créditer vos points et afficher votre solde.
• Vous envoyer les notifications que vous avez choisies.
• Protéger le service contre la fraude (QR à usage unique, alertes sur les scans anormaux).
• Améliorer l'application.
Nous ne vendons pas vos données et nous n'affichons pas de publicité.''', r'''• تشغيل بطاقة الولاء الخاصة بك: إضافة نقاطك وعرض رصيدك.
• إرسال الإشعارات التي اخترتها.
• حماية الخدمة من الاحتيال (رمز QR لاستعمال واحد وتنبيهات للمسح غير الطبيعي).
• تحسين التطبيق.
نحن لا نبيع بياناتك ولا نعرض إعلانات.'''),
  (r'''Ce que voient les commerçants''', r'''ما يراه التجار''', r'''Un commerce voit uniquement votre pseudo, votre solde de points et vos visites chez lui. Il ne voit ni votre e-mail, ni votre téléphone, ni votre activité chez d'autres commerces. Les notes que vous donnez sont affichées sous forme de moyenne.''', r'''يرى المتجر فقط لقبك ورصيد نقاطك وزياراتك لديه. لا يرى بريدك الإلكتروني ولا هاتفك ولا نشاطك في متاجر أخرى. تُعرض تقييماتك على شكل متوسط.'''),
  (r'''Votre position''', r'''موقعك''', r'''Votre position n'est utilisée que si vous l'autorisez, pour afficher les commerces proches et les distances. Elle est calculée sur votre téléphone et n'est jamais enregistrée sur nos serveurs. Vous pouvez la refuser ou la retirer à tout moment dans les réglages du téléphone.''', r'''لا نستخدم موقعك إلا إذا سمحت بذلك، لعرض المتاجر القريبة والمسافات. يُحسب على هاتفك ولا يُسجَّل أبدًا على خوادمنا. يمكنك رفضه أو سحبه في أي وقت من إعدادات الهاتف.'''),
  (r'''Avec qui nous partageons des données''', r'''مع من نشارك البيانات''', r'''Nous faisons appel à des prestataires techniques : Supabase (base de données et connexion), Google Firebase (notifications) et OpenStreetMap (fonds de carte, qui reçoit votre adresse IP). Nous ne partageons pas vos données à des fins publicitaires. Elles peuvent être transmises aux autorités si la loi l'exige.''', r'''نستعين بمزودين تقنيين: Supabase (قاعدة البيانات وتسجيل الدخول) وGoogle Firebase (الإشعارات) وOpenStreetMap (خرائط، ويستلم عنوان IP الخاص بك). لا نشارك بياناتك لأغراض إعلانية. وقد تُسلَّم للسلطات إذا اقتضى القانون ذلك.'''),
  (r'''Durée de conservation''', r'''مدة الاحتفاظ''', r'''Vos données sont conservées tant que votre compte existe. Si vous supprimez votre compte, vos données personnelles sont effacées, sauf obligation légale de les garder.''', r'''نحتفظ ببياناتك ما دام حسابك موجودًا. إذا حذفت حسابك تُمحى بياناتك الشخصية، إلا إذا ألزمنا القانون بالاحتفاظ بها.'''),
  (r'''Vos droits''', r'''حقوقك''', r'''• Accès et copie : Profil → Exporter mes données.
• Rectification : Profil → Modifier mon profil.
• Suppression : Profil → Supprimer mon compte (définitif).
• Notifications : réglables à tout moment dans Profil.
Pour toute autre demande, contactez-nous depuis Profil → Aide.''', r'''• الاطلاع والنسخ: الملف ← تصدير بياناتي.
• التصحيح: الملف ← تعديل ملفي.
• الحذف: الملف ← حذف حسابي (نهائي).
• الإشعارات: قابلة للتعديل في أي وقت من الملف.
لأي طلب آخر تواصل معنا من الملف ← المساعدة.'''),
  (r'''Sécurité, enfants et loi applicable''', r'''الأمان والأطفال والقانون''', r'''Les échanges sont chiffrés (HTTPS), l'accès aux données est limité par des règles strictes, et vous pouvez verrouiller votre portefeuille par un code PIN ou votre empreinte. L'application n'est pas destinée aux enfants. Nous traitons vos données conformément à la loi algérienne n° 18-07 relative à la protection des personnes physiques dans le traitement des données à caractère personnel. Cette politique peut évoluer : la date de dernière mise à jour figure ci-dessous.''', r'''التبادلات مشفرة (HTTPS) والوصول إلى البيانات مقيد بقواعد صارمة، ويمكنك قفل محفظتك برمز PIN أو ببصمتك. التطبيق غير موجه للأطفال. نعالج بياناتك وفق القانون الجزائري رقم 18-07 المتعلق بحماية الأشخاص الطبيعيين في مجال معالجة المعطيات ذات الطابع الشخصي. قد تتغير هذه السياسة: تاريخ آخر تحديث مذكور أدناه.'''),
];

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Politique de confidentialité', 'سياسة الخصوصية'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        for (var i = 0; i < _sections.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}. ${tr(_sections[i].$1, _sections[i].$2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(tr(_sections[i].$3, _sections[i].$4), style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        Text(tr('Dernière mise à jour : 3 octobre 2026', 'آخر تحديث: 3 أكتوبر 2026'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }
}
