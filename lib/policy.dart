import 'package:flutter/material.dart';
import 'main.dart';
import 'nicons.dart';
import 'profile.dart' show supportEmail;
import 'style.dart';
import 'tabs.dart';

// Politique de confidentialité de Nqata.
// ⚠ À faire relire par un juriste avant la publication (Play Store, loi algérienne n° 18-07).
// {EMAIL} est remplacé par supportEmail (défini dans profile.dart).

const _version = '1.0';
const _updatedFr = '7 octobre 2026';
const _updatedAr = '7 أكتوبر 2026';

// Résumé affiché en haut de la page.
const _summaryFr = r'''• Nous ne vendons pas vos données et il n'y a aucune publicité dans l'application.
• Votre position n'est jamais envoyée à nos serveurs.
• Vous pouvez exporter vos données ou supprimer votre compte à tout moment depuis l'application.
• Les commerçants ne voient ni votre e-mail, ni votre numéro de téléphone.''';
const _summaryAr = r'''• لا نبيع بياناتك ولا توجد أي إعلانات في التطبيق.
• موقعك الجغرافي لا يُرسل أبدًا إلى خوادمنا.
• يمكنك تصدير بياناتك أو حذف حسابك في أي وقت من داخل التطبيق.
• لا يرى التجار بريدك الإلكتروني ولا رقم هاتفك.''';

// (titre FR, titre AR, texte FR, texte AR)
const _sections = [
  (
    r'''Qui sommes-nous et champ d'application''',
    r'''من نحن ونطاق هذه السياسة''',
    r'''Nqata est un service de cartes de fidélité qui relie des clients et des commerces partenaires : vous cumulez des points à chaque visite et vous débloquez des récompenses.

Cette politique explique quelles données personnelles nous traitons dans l'application Nqata, pourquoi, avec qui nous les partageons, combien de temps nous les gardons et comment exercer vos droits. En créant un compte, vous confirmez l'avoir lue et acceptée.''',
    r'''نقطة خدمة بطاقات ولاء تربط الزبائن بالمتاجر الشريكة: تجمع النقاط عند كل زيارة وتفتح المكافآت.

توضح هذه السياسة البيانات الشخصية التي نعالجها داخل تطبيق نقطة، ولماذا نعالجها، ومع من نشاركها، ومدة الاحتفاظ بها، وكيف تمارس حقوقك. بإنشاء حساب فإنك تقر بأنك قرأتها ووافقت عليها.''',
  ),
  (
    r'''Les données que vous nous fournissez''',
    r'''البيانات التي تقدمها لنا''',
    r'''• Compte : prénom ou pseudo, adresse e-mail, numéro de téléphone et mot de passe. Le mot de passe est stocké sous forme chiffrée : nous ne pouvons pas le lire.
• Parrainage : le code d'un ami, si vous choisissez de le saisir.
• Avis : la note (et le commentaire facultatif) que vous donnez à un commerce que vous avez visité.
• Profil : l'avatar et les couleurs que vous choisissez.''',
    r'''• الحساب: الاسم أو اللقب والبريد الإلكتروني ورقم الهاتف وكلمة السر. تُخزَّن كلمة السر مشفرة ولا يمكننا قراءتها.
• الترشيح: رمز صديق إذا اخترت إدخاله.
• التقييمات: التقييم (والتعليق الاختياري) الذي تمنحه لمتجر زرته.
• الملف الشخصي: الصورة الرمزية والألوان التي تختارها.''',
  ),
  (
    r'''Les données générées par votre utilisation''',
    r'''البيانات الناتجة عن استعمال التطبيق''',
    r'''• Votre code client et vos QR temporaires (valables environ 60 secondes, à usage unique).
• Votre activité : visites enregistrées par les commerçants, points gagnés, dates d'expiration des points, récompenses utilisées, commerces favoris.
• Vos notifications et vos préférences de notification.
• Votre parrainage : le lien entre vous et la personne qui vous a invité ou que vous avez invitée, vos points de parrainage et le nombre d'amis invités.''',
    r'''• رمز الزبون ورموز QR المؤقتة (صالحة نحو 60 ثانية ولاستعمال واحد).
• نشاطك: الزيارات التي يسجلها التجار، والنقاط المكتسبة، وتواريخ انتهاء النقاط، والمكافآت المستخدمة، والمتاجر المفضلة.
• إشعاراتك وتفضيلات الإشعارات.
• الترشيح: الصلة بينك وبين من دعاك أو من دعوته، ونقاط الترشيح، وعدد الأصدقاء المدعوين.''',
  ),
  (
    r'''Les données techniques''',
    r'''البيانات التقنية''',
    r'''• Un identifiant de notification de votre téléphone (fourni par Google Firebase), nécessaire pour vous envoyer des notifications, même lorsque l'application est fermée. Il est supprimé quand vous vous déconnectez ou désactivez les notifications.
• Votre adresse IP, traitée par nos prestataires techniques lors de chaque échange avec nos serveurs, pour assurer le fonctionnement et la sécurité du service.''',
    r'''• معرّف إشعارات هاتفك (توفره Google Firebase)، وهو ضروري لإرسال الإشعارات إليك حتى عندما يكون التطبيق مغلقًا. يُحذف عند تسجيل الخروج أو إيقاف الإشعارات.
• عنوان IP الخاص بك، ويعالجه مزودونا التقنيون عند كل اتصال بخوادمنا لضمان عمل الخدمة وأمنها.''',
  ),
  (
    r'''Les données qui restent sur votre téléphone''',
    r'''البيانات التي تبقى على هاتفك''',
    r'''• Votre code PIN : il n'est jamais stocké en clair, seulement sous forme chiffrée (hachée et salée), et il ne quitte pas votre téléphone.
• Votre empreinte digitale : elle est gérée par le système de votre téléphone. Nqata ne reçoit et ne stocke aucune donnée biométrique : l'application reçoit seulement la réponse « reconnu » ou « non reconnu ».
• Vos réglages (langue, thème, taille du texte, avatar) et l'état du tutoriel.
• Une copie de vos cartes, points et transactions, pour que l'application reste utilisable sans connexion. Elle est effacée si vous désinstallez l'application.''',
    r'''• رمز PIN: لا يُخزَّن أبدًا بشكل مقروء، بل مشفرًا فقط، ولا يغادر هاتفك.
• بصمتك: يديرها نظام هاتفك. لا يستلم نقطة ولا يخزن أي بيانات بيومترية، فالتطبيق يتلقى فقط إجابة «تم التعرف» أو «لم يتم التعرف».
• إعداداتك (اللغة والسمة وحجم النص والصورة الرمزية) وحالة الشرح التعريفي.
• نسخة من بطاقاتك ونقاطك ومعاملاتك ليبقى التطبيق قابلاً للاستعمال دون اتصال. تُمحى عند حذف التطبيق.''',
  ),
  (
    r'''Votre position''',
    r'''موقعك الجغرافي''',
    r'''Nous n'utilisons votre position que si vous l'autorisez, pour afficher les commerces proches et les distances. Elle est calculée sur votre téléphone et n'est jamais envoyée ni enregistrée sur nos serveurs. Vous pouvez refuser l'autorisation, ou la retirer à tout moment dans les réglages de votre téléphone (Profil → Paramètres → Autorisation de localisation).''',
    r'''لا نستخدم موقعك إلا إذا سمحت بذلك، لعرض المتاجر القريبة والمسافات. يُحسب على هاتفك ولا يُرسل ولا يُسجَّل أبدًا على خوادمنا. يمكنك رفض الإذن أو سحبه في أي وقت من إعدادات هاتفك (الملف ← الإعدادات ← إذن الموقع).''',
  ),
  (
    r'''Pourquoi nous utilisons vos données''',
    r'''لماذا نستخدم بياناتك''',
    r'''• Fournir le service : créer votre compte, créditer vos points, afficher votre solde, gérer les récompenses et leur expiration.
• Gérer le parrainage : attribuer les points de parrainage et prévenir la personne qui vous a invité.
• Vous envoyer les notifications que vous avez activées (points gagnés, récompenses, offres, expiration prochaine de vos points).
• Protéger le service : QR à usage unique, limitation des abus et détection des fraudes.
• Répondre à vos demandes et améliorer l'application.

Nous traitons vos données sur la base de votre consentement, donné à la création du compte, et pour exécuter le service que vous demandez. Vous pouvez retirer votre consentement à tout moment en supprimant votre compte. Nous ne vendons pas vos données et nous n'affichons aucune publicité.''',
    r'''• تقديم الخدمة: إنشاء حسابك وإضافة نقاطك وعرض رصيدك وإدارة المكافآت وانتهاء صلاحية النقاط.
• إدارة الترشيح: منح نقاط الترشيح وإبلاغ من دعاك.
• إرسال الإشعارات التي فعّلتها (النقاط المكتسبة والمكافآت والعروض واقتراب انتهاء النقاط).
• حماية الخدمة: رمز QR لاستعمال واحد والحد من إساءة الاستخدام واكتشاف الاحتيال.
• الرد على طلباتك وتحسين التطبيق.

نعالج بياناتك بناءً على موافقتك عند إنشاء الحساب ولتنفيذ الخدمة التي تطلبها. يمكنك سحب موافقتك في أي وقت بحذف حسابك. لا نبيع بياناتك ولا نعرض أي إعلانات.''',
  ),
  (
    r'''Ce que voient les autres''',
    r'''ما يراه الآخرون''',
    r'''• Les commerçants : un commerce voit votre pseudo, votre solde de points chez lui et vos visites chez lui. Il ne voit ni votre e-mail, ni votre téléphone, ni votre activité chez d'autres commerces.
• Les autres utilisateurs et les commerces : si vous publiez un avis, votre pseudo, votre note, votre commentaire et la date sont affichés publiquement sur la page du commerce. Ne mettez pas d'informations personnelles dans vos commentaires.
• Le parrainage : la personne dont vous saisissez le code voit votre pseudo dans une notification, et vous voyez le sien. Rien d'autre n'est partagé entre vous.''',
    r'''• التجار: يرى المتجر لقبك ورصيد نقاطك لديه وزياراتك لديه. لا يرى بريدك الإلكتروني ولا هاتفك ولا نشاطك في متاجر أخرى.
• المستخدمون الآخرون والمتاجر: إذا نشرت تقييمًا، يظهر لقبك وتقييمك وتعليقك وتاريخه علنًا في صفحة المتجر. لا تكتب معلومات شخصية في تعليقاتك.
• الترشيح: من أدخلت رمزه يرى لقبك في إشعار، وترى أنت لقبه. لا يُشارك بينكما أي شيء آخر.''',
  ),
  (
    r'''Avec qui nous partageons des données''',
    r'''مع من نشارك البيانات''',
    r'''Pour faire fonctionner Nqata, nous faisons appel à des prestataires techniques qui traitent des données pour notre compte :
• Supabase : base de données, connexion et stockage. Nos données sont hébergées en Irlande (Union européenne), où s'applique le RGPD.
• Google Firebase : envoi des notifications.
• OpenStreetMap : fonds de carte (ses serveurs reçoivent votre adresse IP et la zone de carte affichée).

Nous ne partageons pas vos données à des fins publicitaires. Elles peuvent être communiquées aux autorités compétentes si la loi l'exige.

Vos données sont donc traitées en dehors de l'Algérie, principalement en Irlande. Google Firebase peut aussi traiter l'identifiant de notification dans d'autres pays. Nous veillons à ne confier à ces prestataires que les données nécessaires au service.''',
    r'''لتشغيل نقطة نستعين بمزودين تقنيين يعالجون البيانات لحسابنا:
• Supabase: قاعدة البيانات وتسجيل الدخول والتخزين. تُستضاف بياناتنا في أيرلندا (الاتحاد الأوروبي) حيث يُطبَّق نظام RGPD.
• Google Firebase: إرسال الإشعارات.
• OpenStreetMap: خرائط (تستلم خوادمه عنوان IP الخاص بك ومنطقة الخريطة المعروضة).

لا نشارك بياناتك لأغراض إعلانية. وقد تُسلَّم للسلطات المختصة إذا اقتضى القانون ذلك.

لذلك تُعالَج بياناتك خارج الجزائر، وخاصة في أيرلندا. وقد تعالج Google Firebase معرّف الإشعارات في بلدان أخرى. نحرص على ألا نمنح هؤلاء المزودين إلا البيانات اللازمة للخدمة.''',
  ),
  (
    r'''Durée de conservation''',
    r'''مدة الاحتفاظ''',
    r'''• Vos données de compte et d'activité sont conservées tant que votre compte existe.
• Les QR temporaires sont supprimés peu après leur utilisation ou leur expiration.
• Quand vous supprimez votre compte, vos données personnelles sont effacées de façon définitive, sauf celles que la loi nous oblige à conserver.
• Les points expirent selon la durée de validité fixée par chaque commerce ; un historique technique des expirations peut être conservé tant que votre compte existe.''',
    r'''• نحتفظ ببيانات حسابك ونشاطك ما دام حسابك موجودًا.
• تُحذف رموز QR المؤقتة بعد وقت قصير من استعمالها أو انتهاء صلاحيتها.
• عند حذف حسابك تُمحى بياناتك الشخصية نهائيًا، باستثناء ما يلزمنا القانون بالاحتفاظ به.
• تنتهي صلاحية النقاط وفق المدة التي يحددها كل متجر، وقد يُحتفظ بسجل تقني للانتهاءات ما دام حسابك موجودًا.''',
  ),
  (
    r'''Vos droits''',
    r'''حقوقك''',
    r'''Conformément à la loi algérienne n° 18-07, vous avez le droit d'être informé, d'accéder à vos données, de les faire rectifier, de vous opposer à leur traitement pour des motifs légitimes et de retirer votre consentement. Dans l'application :
• Accès et copie : Profil → Paramètres → Exporter mes données.
• Rectification du nom, de l'avatar et des couleurs : Profil → Personnaliser mon profil.
• Suppression du compte et de toutes les données associées : Profil → Paramètres → Supprimer mon compte (définitif).
• Notifications : Profil → Paramètres → Notifications.
• Localisation : réglages de votre téléphone.

Pour modifier votre numéro de téléphone ou votre e-mail, ou pour toute autre demande, écrivez-nous à {EMAIL}. Nous répondons dans un délai raisonnable.

Vous pouvez aussi saisir l'Autorité nationale de protection des données à caractère personnel (ANPDP) si vous estimez que vos droits ne sont pas respectés.''',
    r'''وفقًا للقانون الجزائري رقم 18-07، يحق لك أن تُعلَم، وأن تطلع على بياناتك، وأن تصححها، وأن تعترض على معالجتها لأسباب مشروعة، وأن تسحب موافقتك. داخل التطبيق:
• الاطلاع والنسخ: الملف ← الإعدادات ← تصدير بياناتي.
• تعديل الاسم والصورة والألوان: الملف ← تخصيص ملفي.
• حذف الحساب وكل البيانات المرتبطة به: الملف ← الإعدادات ← حذف حسابي (نهائي).
• الإشعارات: الملف ← الإعدادات ← الإشعارات.
• الموقع: إعدادات هاتفك.

لتعديل رقم هاتفك أو بريدك الإلكتروني أو لأي طلب آخر، راسلنا على {EMAIL}. نرد في أجل معقول.

يمكنك أيضًا اللجوء إلى السلطة الوطنية لحماية المعطيات ذات الطابع الشخصي إذا رأيت أن حقوقك غير محترمة.''',
  ),
  (
    r'''Sécurité''',
    r'''الأمان''',
    r'''Nous protégeons vos données par plusieurs mesures : échanges chiffrés (HTTPS), mots de passe chiffrés, accès aux données limité par des règles strictes (chaque utilisateur n'accède qu'à ses propres données), QR à usage unique et de courte durée, verrouillage du portefeuille par code PIN ou empreinte.

Aucun système n'est infaillible. Protégez votre mot de passe et votre code PIN, ne les partagez avec personne, et prévenez-nous si vous pensez que votre compte a été utilisé à votre insu.''',
    r'''نحمي بياناتك بعدة إجراءات: اتصالات مشفرة (HTTPS)، وكلمات سر مشفرة، ووصول إلى البيانات مقيد بقواعد صارمة (لا يصل كل مستخدم إلا إلى بياناته)، ورمز QR لاستعمال واحد ومدة قصيرة، وقفل المحفظة برمز PIN أو بالبصمة.

لا يوجد نظام معصوم من الخطأ. احمِ كلمة سرك ورمز PIN ولا تشاركهما مع أحد، وأبلغنا إذا ظننت أن حسابك استُعمل دون علمك.''',
  ),
  (
    r'''Mineurs''',
    r'''القاصرون''',
    r'''Nqata n'est pas destinée aux enfants. Si vous êtes mineur, utilisez l'application uniquement avec l'accord de votre parent ou représentant légal. Si vous pensez qu'un enfant nous a transmis des données sans accord, contactez-nous pour que nous les supprimions.''',
    r'''نقطة غير موجهة للأطفال. إذا كنت قاصرًا فاستعمل التطبيق بموافقة أحد والديك أو وليك الشرعي فقط. وإذا ظننت أن طفلاً زودنا ببياناته دون موافقة، فراسلنا لنحذفها.''',
  ),
  (
    r'''Modifications de cette politique''',
    r'''تعديل هذه السياسة''',
    r'''Nous pouvons mettre à jour cette politique, par exemple si nous ajoutons une fonctionnalité. La date de dernière mise à jour figure en bas de cette page. En cas de changement important, nous vous en informerons dans l'application.''',
    r'''قد نحدّث هذه السياسة، مثلاً عند إضافة ميزة جديدة. تاريخ آخر تحديث مذكور أسفل هذه الصفحة. وعند أي تغيير مهم سنُعلمك داخل التطبيق.''',
  ),
  (
    r'''Nous contacter''',
    r'''الاتصال بنا''',
    r'''Pour toute question sur cette politique ou sur vos données : {EMAIL}''',
    r'''لأي سؤال حول هذه السياسة أو بياناتك: {EMAIL}''',
  ),
];

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

  String _t(String fr, String ar) => tr(fr, ar).replaceAll('{EMAIL}', supportEmail);

  Widget _summary(BuildContext c) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: nTint(c), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            NIcon('shield', size: 24, color: nInk(c), accent: nGold(c)),
            const SizedBox(width: 12),
            Text(tr('En bref', 'باختصار'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Text(tr(_summaryFr, _summaryAr), style: const TextStyle(fontSize: 14.5, height: 1.55)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Politique de confidentialité', 'سياسة الخصوصية'))),
      body: SelectionArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 36), children: [
          FadeSlideIn(child: _summary(context)),
          for (var i = 0; i < _sections.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ${tr(_sections[i].$1, _sections[i].$2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: lang == 'ar' ? 0 : -0.2)),
                  const SizedBox(height: 8),
                  Text(_t(_sections[i].$3, _sections[i].$4), style: TextStyle(fontSize: 15, height: 1.6, color: nInk(context).withOpacity(0.86))),
                ]),
              ),
            ),
          const SizedBox(height: 30),
          Text('${tr('Version', 'الإصدار')} $_version · ${tr('Dernière mise à jour', 'آخر تحديث')} : ${tr(_updatedFr, _updatedAr)}', style: TextStyle(color: nMuted(context), fontSize: 12)),
        ]),
      ),
    );
  }
}
