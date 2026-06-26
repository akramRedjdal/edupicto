import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── Couleurs EduPicto (DA du poster) ───────────────────────────────────────
const kOrange = Color(0xFFFF6B1A);
const kOrangeSoft = Color(0xFFFFF0E5);
const kOrangeMid = Color(0xFFFFD8B0);
const kPink = Color(0xFFE83E8C);
const kPinkSoft = Color(0xFFFEF0F8);
const kBg = Color(0xFFF7F7F7);
const kCardBg = Color(0xFFFFFFFF);
const kTextDark = Color(0xFF1A1A1A);
const kTextMid = Color(0xFF666666);
const kTextLight = Color(0xFF999999);

// ─── URL du serveur backend ─────────────────────────────────────────────────
// Par défaut localhost (dev). Pour un build déployé, surcharger au build :
//   flutter build web --dart-define=SERVER_URL=https://<user>-<space>.hf.space
const String kServerUrl =
    String.fromEnvironment('SERVER_URL', defaultValue: 'http://localhost:5006');

// ─── Modèle Histoire ────────────────────────────────────────────────────────
class Histoire {
  final String titre;
  final String sousTitre;
  final String texte;
  final String contexte;
  final String emoji;
  final String tag;
  bool favori;

  Histoire({
    required this.titre,
    required this.sousTitre,
    required this.texte,
    required this.contexte,
    required this.emoji,
    required this.tag,
    this.favori = false,
  });
}

// ─── Données (Mises à jour avec tes textes) ──────────────────────────────────
final List<Histoire> histoiresGlobales = [
  Histoire(
    titre: "Mala et Poline, des petites filles du Groenland",
    sousTitre: "Texte 1",
    texte: """Mala et sa sœur Poline ont dix ans. Elles habitent 
    une jolie maison en bois bleu au bord de la mer. 
    La maison de leurs voisins est rouge. La famille de 
    Mala et Poline fait partie du peuple Inuit.
    L’hiver, il fait très froid dehors. Mais Mala et 
    Poline n’ont pas froid. Leur maison est bien isolée 
    et elle est bien chauffée. Tous les matins, Mala et 
    Poline prennent une douche chaude avant d’aller à 
    l’école. Avant de sortir, elles enfilent une parka 
    fourrée et des bottes en peau de phoque.
    Comme tous les Inuits, Mala et Poline mangent des 
    poissons séchés, des poissons frais, de la viande 
    de phoque, de baleine et de caribou. Elles 
    mangent peu de légumes car ils coutent très cher.
    Mala et Poline aiment beaucoup leur pays, même 
    si en hiver elles ne voient presque pas le soleil 
    pendant trois mois. Les deux fillettes adorent les 
    jours de fête. Ces jours-là, elles portent le 
    costume traditionnel des Esquimaux : une tunique 
    avec des perles multicolores et une large ceinture 
    brodée""",
    contexte: ' ',
    emoji: '🏔️',
    tag: 'Voyage',
  ),
  Histoire(
    titre: "La salade composée de Léo",
    sousTitre: "Texte 2",
    texte: """Léo est dans la cuisine. Dans l’après-midi, il a des invités.
    Il decide de faire une salade composée pour ses invités.
    Sur une table, il prépare les ingrédients et le
    matériel.
    Il égoutte le maïs avec la passoire.
    Il lave, il épluche et il râpe des carottes.
    Il coupe le gruyère en petits cubes.
    Il retire la peau et le noyau de l’avocat.
    Il coupe l’avocat en fines lamelles.
    Il fait ensuite une vinaigrette avec l’huile, le
    vinaigre, le sel et le poivre.
    Il verse la vinaigrette dans un saladier avec les
    carottes, le maïs, l’avocat et le gruyère.
    Il mélange.
    La salade composée est prête.""",
    contexte: 'contexte_texte13',
    emoji: '🏫',
    tag: 'Cuisine',
  ),
  Histoire(
    titre: "Tarte aux pommes",
    sousTitre: "Texte 3",
    texte: '1. Tu verses la farine dans le saladier. 2. Tu casses l’œuf dans le saladier. 3. Tu ajoutes le beurre, du sel et de l’eau. 4. Tu mélanges tout. 5. Tu malaxes la pâte. 6. Tu étales la pâte avec un rouleau. 7. Tu poses la pâte dans la tourtière. 8. Tu disposes les pommes sur la pâte. 9. Tu places dans le four. 10. Trente minutes plus tard, tu enlèves la tarte du four et tu la manges.',
    contexte: 'contexte_texte17',
    emoji: '🍎',
    tag: 'Recette de Cuisine',
  ),
  Histoire(
    titre: "La polysémie du mot Avocat",
    sousTitre: "Texte 4",
    texte: 'Dans la cuisine, Léo mange un avocat pendant que son voisin parle avec son avocat.',
    contexte: ' ',
    emoji: '',
    tag: 'Polysémie',
  ),
];

// ─── App ────────────────────────────────────────────────────────────────────
void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: kOrange,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EduPictoApp());
}

class EduPictoApp extends StatelessWidget {
  const EduPictoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPicto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kOrange),
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'Nunito',
        appBarTheme: const AppBarTheme(
          backgroundColor: kOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── Shell avec BottomNav ────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _toggleFavori(Histoire h) {
    setState(() => h.favori = !h.favori);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      AccueilPage(histoires: histoiresGlobales, onToggleFavori: _toggleFavori),
      BibliothequePage(histoires: histoiresGlobales, onToggleFavori: _toggleFavori),
      FavorisPage(histoires: histoiresGlobales, onToggleFavori: _toggleFavori),
      const ReglagePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kOrange,
          unselectedItemColor: kTextLight,
          backgroundColor: Colors.white,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
            const BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Bibliothèque'),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.favorite_rounded),
                  if (histoiresGlobales.any((h) => h.favori))
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: kPink, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              label: 'Favoris',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Réglages'),
          ],
        ),
      ),
    );
  }
}

// ─── Page Accueil ────────────────────────────────────────────────────────────
class AccueilPage extends StatelessWidget {
  final List<Histoire> histoires;
  final void Function(Histoire) onToggleFavori;

  const AccueilPage({super.key, required this.histoires, required this.onToggleFavori});

  @override
  Widget build(BuildContext context) {
    final recentes = histoires.take(2).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _AccueilHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bonjour ! 👋', style: TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w900, color: kTextDark),
                      children: [
                        TextSpan(text: 'Quelle histoire on '),
                        TextSpan(text: 'explore', style: TextStyle(color: kOrange)),
                        TextSpan(text: ' ?'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _BigNavCard(
                      emoji: '📚', label: 'Bibliothèque', sublabel: 'Toutes les histoires',
                      color: kOrange, bgColor: kOrangeSoft, borderColor: kOrangeMid,
                      onTap: () {
                        context.findAncestorStateOfType<_MainShellState>()?.setState(() => context.findAncestorStateOfType<_MainShellState>()?._index = 1);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigNavCard(
                      emoji: '❤️', label: 'Favoris', sublabel: 'Mes préférées',
                      color: kPink, bgColor: kPinkSoft, borderColor: const Color(0xFFFFB8D8),
                      onTap: () {
                        context.findAncestorStateOfType<_MainShellState>()?.setState(() => context.findAncestorStateOfType<_MainShellState>()?._index = 2);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _GenererCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GenererPage()),
                ),
              ),
            ),
          ),
          if (recentes.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text('RÉCEMMENT OUVERT', style: TextStyle(color: kTextLight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  recentes.map((h) => _HistoireListItem(histoire: h, onToggleFavori: onToggleFavori)).toList(),
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

class _AccueilHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      // Changement du fond en blanc pour que ton nouveau logo s'intègre parfaitement
      color: kOrange,
      child: SafeArea(
        bottom: false,
        child: Container(
          // Ajustement des marges intérieures pour un rendu plus équilibré
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              // Insertion de ton nouveau logo (qui contient déjà le dessin et le texte)
              Image.asset(
                'assets/logo_edupicto.png',
                height: 55, // Hauteur idéale pour occuper l'espace proprement
                fit: BoxFit.contain,
              ),
              const Spacer(),
              // Conservation de la pièce de puzzle à droite
              const Text('🧩', style: TextStyle(fontSize: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigNavCard extends StatelessWidget {
  final String emoji; final String label; final String sublabel;
  final Color color; final Color bgColor; final Color borderColor; final VoidCallback onTap;
  const _BigNavCard({required this.emoji, required this.label, required this.sublabel, required this.color, required this.bgColor, required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor, width: 1.5)),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(sublabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// ─── Page Bibliothèque ───────────────────────────────────────────────────────
class BibliothequePage extends StatefulWidget {
  final List<Histoire> histoires; final void Function(Histoire) onToggleFavori;
  const BibliothequePage({super.key, required this.histoires, required this.onToggleFavori});
  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  String _query = '';
  List<Histoire> get _filtered => widget.histoires.where((h) => h.titre.toLowerCase().contains(_query.toLowerCase()) || h.tag.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true, expandedHeight: 120, backgroundColor: kOrange, automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
              title: const Text('📚 Bibliothèque', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              background: Container(color: kOrange),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                color: kOrange, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Chercher une histoire…', hintStyle: TextStyle(color: kTextLight, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: kTextLight, size: 20), border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('${_filtered.length} HISTOIRE${_filtered.length > 1 ? 'S' : ''}', style: const TextStyle(color: kTextLight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _filtered.map((h) => _HistoireListItem(histoire: h, onToggleFavori: widget.onToggleFavori)).toList(),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

// ─── Page Favoris ────────────────────────────────────────────────────────────
class FavorisPage extends StatelessWidget {
  final List<Histoire> histoires; final void Function(Histoire) onToggleFavori;
  const FavorisPage({super.key, required this.histoires, required this.onToggleFavori});

  @override
  Widget build(BuildContext context) {
    final favoris = histoires.where((h) => h.favori).toList();
    return Scaffold(
      backgroundColor: kPinkSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true, backgroundColor: kPink, automaticallyImplyLeading: false,
            title: const Text('❤️ Mes Favoris', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: Container(height: 16, decoration: const BoxDecoration(color: kPinkSoft, borderRadius: BorderRadius.vertical(top: Radius.circular(16)))),
            ),
          ),
          if (favoris.isEmpty) SliverFillRemaining(child: _FavorisVide()) else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text('${favoris.length} HISTOIRE${favoris.length > 1 ? 'S' : ''} SAUVEGARDÉE${favoris.length > 1 ? 'S' : ''}', style: const TextStyle(color: kPink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  favoris.map((h) => _HistoireListItem(histoire: h, onToggleFavori: onToggleFavori, accentColor: kPink)).toList(),
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

class _FavorisVide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Pas encore de favoris', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kTextDark), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Appuie sur le ❤️ dans une histoire\npour la retrouver ici !', style: TextStyle(fontSize: 13, color: kTextMid, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: kPink, borderRadius: BorderRadius.circular(20)),
              child: const Text('Voir la bibliothèque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page Réglages ───────────────────────────────────────────────────────────
class ReglagePage extends StatelessWidget {
  const ReglagePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, backgroundColor: kOrange, automaticallyImplyLeading: false, title: Text('⚙️ Réglages', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ReglageSection(titre: 'Application', items: [_ReglageItem(icone: Icons.language_rounded, label: 'Langue', valeur: 'Français'), _ReglageItem(icone: Icons.text_fields_rounded, label: 'Taille du texte', valeur: 'Normal')]),
                const SizedBox(height: 16),
                _ReglageSection(titre: 'Serveur', items: [_ReglageItem(icone: Icons.dns_rounded, label: 'URL du serveur', valeur: kServerUrl)]),
                const SizedBox(height: 16),
                _ReglageSection(titre: 'À propos', items: [_ReglageItem(icone: Icons.info_outline_rounded, label: 'Version', valeur: '1.0.0'), _ReglageItem(icone: Icons.school_rounded, label: 'Projet ESIEE Paris', valeur: '')]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReglageSection extends StatelessWidget {
  final String titre; final List<Widget> items;
  const _ReglageSection({required this.titre, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(titre.toUpperCase(), style: const TextStyle(color: kTextLight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8))),
      Container(decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEEE))), child: Column(children: items)),
    ]);
  }
}

class _ReglageItem extends StatelessWidget {
  final IconData icone; final String label; final String valeur;
  const _ReglageItem({required this.icone, required this.label, required this.valeur});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icone, color: kOrange, size: 20), const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
        if (valeur.isNotEmpty) Text(valeur, style: const TextStyle(fontSize: 13, color: kTextLight, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, color: kTextLight, size: 18),
      ]),
    );
  }
}

// ─── Item d'histoire réutilisable ────────────────────────────────────────────
class _HistoireListItem extends StatelessWidget {
  final Histoire histoire; final void Function(Histoire) onToggleFavori; final Color accentColor;
  const _HistoireListItem({required this.histoire, required this.onToggleFavori, this.accentColor = kOrange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisionneuseHistoirePage(histoire: histoire, onToggleFavori: onToggleFavori))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: accentColor, width: 3.5)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Text(histoire.emoji, style: const TextStyle(fontSize: 26)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(histoire.titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)), const SizedBox(height: 2),
              Text(histoire.texte, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kTextMid, fontWeight: FontWeight.w600)), const SizedBox(height: 5),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kOrangeSoft, borderRadius: BorderRadius.circular(6)), child: Text(histoire.tag, style: const TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w700))),
            ])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                onToggleFavori(histoire);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(histoire.favori ? '❤️ Ajouté aux favoris !' : '🤍 Retiré des favoris', style: const TextStyle(fontWeight: FontWeight.w700)), backgroundColor: histoire.favori ? kPink : kTextMid, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 1)));
              },
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child), child: Icon(histoire.favori ? Icons.favorite_rounded : Icons.favorite_border_rounded, key: ValueKey(histoire.favori), color: histoire.favori ? kPink : kTextLight, size: 22)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Carte "Générer une histoire" (Accueil) ──────────────────────────────────
class _GenererCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GenererCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kOrange, kPink]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: kOrange.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Générer une histoire', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('IA + pictogrammes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Page Génération (Mistral + pictogrammes) ────────────────────────────────
class GenererPage extends StatefulWidget {
  const GenererPage({super.key});
  @override
  State<GenererPage> createState() => _GenererPageState();
}

class _GenererPageState extends State<GenererPage> {
  final TextEditingController _theme = TextEditingController();
  List<dynamic> _motsResultat = [];
  String? _texteGenere;
  bool _enChargement = false;
  String? _erreur;

  Future<void> genererEtPictogramiser() async {
    setState(() { _enChargement = true; _erreur = null; _motsResultat = []; _texteGenere = null; });
    try {
      final reponse = await http.post(
        Uri.parse('$kServerUrl/generer'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'theme': _theme.text.trim()}),
      );

      if (reponse.statusCode == 200) {
        final data = jsonDecode(utf8.decode(reponse.bodyBytes));
        final list = data['flux_de_lecture'] as List<dynamic>;
        for (var mot in list) {
          final String txt = mot['mot'] ?? '';
          mot['is_break'] = txt.contains('.') || txt.contains('!') || txt.contains('?') || txt.contains('\n');
        }
        setState(() { _motsResultat = list; _texteGenere = data['texte'] as String?; });
      } else {
        String msg = 'Erreur serveur (${reponse.statusCode})';
        try { msg = (jsonDecode(utf8.decode(reponse.bodyBytes))['erreur'] ?? msg).toString(); } catch (_) {}
        setState(() => _erreur = msg);
      }
    } catch (e) {
      setState(() => _erreur = 'Impossible de joindre le serveur Python');
    } finally {
      setState(() => _enChargement = false);
    }
  }

  @override
  void dispose() { _theme.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    List<List<dynamic>> phrases = [[]];
    for (var mot in _motsResultat) {
      phrases.last.add(mot);
      if (mot['is_break'] == true) phrases.add([]);
    }
    phrases.removeWhere((p) => p.isEmpty);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('✨ Générer', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      body: Column(
        children: [
          // Zone de saisie du thème + bouton
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
                  child: TextField(
                    controller: _theme,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Thème (ex: une recette, une journée…)',
                      hintStyle: TextStyle(color: kTextLight, fontSize: 13),
                      prefixIcon: Icon(Icons.lightbulb_outline_rounded, color: kOrange, size: 20),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enChargement ? null : genererEtPictogramiser,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_enChargement ? 'Génération…' : 'Générer le texte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _enChargement
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: kOrange), SizedBox(height: 16), Text('Génération + analyse…', style: TextStyle(color: kTextMid, fontWeight: FontWeight.w700))]))
                : _erreur != null
                    ? _ErreurWidget(message: _erreur!, onRetry: genererEtPictogramiser)
                    : _motsResultat.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Choisis un thème (ou laisse vide) puis appuie sur Générer.', textAlign: TextAlign.center, style: TextStyle(color: kTextMid, fontWeight: FontWeight.w600, fontSize: 14))))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: phrases.length,
                            itemBuilder: (context, indexPhrase) => _PhraseCard(numero: indexPhrase + 1, mots: phrases[indexPhrase]),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Page Visionneuse Connectée à server.py ──────────────────────────────────
class VisionneuseHistoirePage extends StatefulWidget {
  final Histoire histoire; final void Function(Histoire) onToggleFavori;
  const VisionneuseHistoirePage({super.key, required this.histoire, required this.onToggleFavori});
  @override
  State<VisionneuseHistoirePage> createState() => _VisionneuseHistoirePageState();
}

class _VisionneuseHistoirePageState extends State<VisionneuseHistoirePage> {
  List<dynamic> _motsResultat = [];
  bool _enChargement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    envoyerAuServeur();
  }

  Future<void> envoyerAuServeur() async {
    setState(() { _enChargement = true; _erreur = null; });
    try {
      final reponse = await http.post(
        Uri.parse('$kServerUrl/pictogramiser'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'texte': widget.histoire.texte}),
      );

      if (reponse.statusCode == 200) {
        final data = jsonDecode(utf8.decode(reponse.bodyBytes));
        final list = data['flux_de_lecture'] as List<dynamic>;
        
        for (var mot in list) {
          final String txt = mot['mot'] ?? '';
          if (txt.contains('.') || txt.contains('!') || txt.contains('?') || txt.contains('\n')) {
            mot['is_break'] = true;
          } else {
            mot['is_break'] = false;
          }
        }
        setState(() { _motsResultat = list; });
      } else {
        setState(() => _erreur = 'Erreur serveur (${reponse.statusCode})');
      }
    } catch (e) {
      setState(() => _erreur = 'Impossible de joindre le serveur Python');
    } finally {
      setState(() => _enChargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<List<dynamic>> phrases = [[]];
    for (var mot in _motsResultat) {
      phrases.last.add(mot);
      if (mot['is_break'] == true) phrases.add([]);
    }
    phrases.removeWhere((p) => p.isEmpty);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(widget.histoire.titre, style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis),
        actions: [
          StatefulBuilder(builder: (ctx, setLocal) => IconButton(
            icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child), child: Icon(widget.histoire.favori ? Icons.favorite_rounded : Icons.favorite_border_rounded, key: ValueKey(widget.histoire.favori), color: widget.histoire.favori ? const Color(0xFFFFB0D0) : Colors.white, size: 24)),
            onPressed: () { widget.onToggleFavori(widget.histoire); setLocal(() {}); ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.histoire.favori ? '❤️ Ajouté aux favoris !' : '🤍 Retiré des favoris', style: const TextStyle(fontWeight: FontWeight.w700)), backgroundColor: widget.histoire.favori ? kPink : kTextMid, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 1))); },
          )),
          if (_erreur != null) IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: envoyerAuServeur),
        ],
      ),
      body: _enChargement
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: kOrange), SizedBox(height: 16), Text('Analyse en cours…', style: TextStyle(color: kTextMid, fontWeight: FontWeight.w700))]))
          : _erreur != null
              ? _ErreurWidget(message: _erreur!, onRetry: envoyerAuServeur)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: phrases.length,
                  itemBuilder: (context, indexPhrase) => _PhraseCard(numero: indexPhrase + 1, mots: phrases[indexPhrase]),
                ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  final int numero; final List<dynamic> mots;
  const _PhraseCard({required this.numero, required this.mots});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardBg, 
        borderRadius: BorderRadius.circular(16), 
        border: const Border(left: BorderSide(color: kOrange, width: 3)), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), 
            decoration: BoxDecoration(color: kOrangeSoft, borderRadius: BorderRadius.circular(8)), 
            child: Text('Phrase $numero', style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w800))
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
            children: mots.map<Widget>((mot) {
              final String? picto = mot['picto'];
              final String texte = mot['mot'] ?? '';
              final String? type = mot['type'];

              if (picto == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(texte, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: kTextMid)),
                );
              }

              // 🎯 APPLICATION STRICTE DE LA CLÉ DE FITZGERALD (Norme TSA / CAA)
              Color borderColor = kOrangeMid;
              Color backgroundColor = kOrangeSoft;

              if (type == 'verbe') {
                borderColor = const Color(0xFF2E7D32); // Vert officiel pour les Actions
                backgroundColor = const Color(0xFFE8F5E9); // Fond vert pastel relaxant
              } else if (type == 'propre') {
                borderColor = const Color(0xFFF5B041); // Jaune/Orange foncé lisible pour les Personnes
                backgroundColor = const Color(0xFFFEF9E7); // Fond jaune pastel très doux
              } else if (type == 'commun') {
                borderColor = kOrange; // Orange officiel ARASAAC pour les objets et aliments
                backgroundColor = kOrangeSoft;
              }

              final bool isNumericId = int.tryParse(picto) != null;

              return Container(
                width: 88, height: 108,
                decoration: BoxDecoration(
                  color: backgroundColor, 
                  borderRadius: BorderRadius.circular(10), 
                  border: Border.all(color: borderColor, width: 2.5) // Bordure renforcée pour l'ancrage visuel
                ),
                padding: const EdgeInsets.all(5),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(
                    child: isNumericId
                        ? Image.network(
                            'https://static.arasaac.org/pictograms/$picto/${picto}_300.png',
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, size: 24, color: kTextLight),
                          )
                        : Image.asset(
                            'assets/Picto_Arasaac/$picto',
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported_rounded, size: 24, color: kTextLight),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texte.trim(), 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextDark), 
                    textAlign: TextAlign.center, 
                    overflow: TextOverflow.ellipsis
                  ),
                ]),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

class _ErreurWidget extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErreurWidget({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('😕', style: TextStyle(fontSize: 48)), const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(onTap: onRetry, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(20)), child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
        ]),
      ),
    );
  }
}