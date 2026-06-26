# EduPicto — Aide à la lecture en pictogrammes

Application d'aide à la lecture pour enfants avec autisme. Un texte est transformé en
**pictogrammes ARASAAC** (avec le mot écrit dessous), en s'appuyant sur une
**ontologie de concepts** et une **résolution de coréférence** (les pronoms « il /
elle » renvoient au bon personnage).

> **Projet étudiant — ESIEE Paris**, développé par :
> - **Rayhana TRUONG** — rayhana.truong@edu.esiee.fr
> - **Guillaume-Alexandre STRABA** — guillaume-alexandre.straba@edu.esiee.fr
> - **Antoine TAVERNIER** — antoine.tavernier@edu.esiee.fr
> - **Leyson YABA-LEY** — leyson.yaba-ley@edu.esiee.fr

## Architecture

```
┌─────────────────┐   POST /pictogramiser   ┌──────────────────────────┐
│  App Flutter    │ ─────────────────────►  │  Serveur Python (Flask)  │
│  (web/mobile)   │   POST /generer         │                          │
│                 │ ◄─────────────────────  │  • spaCy (tokenisation)  │
│  affiche pictos │   {mot, picto, type}    │  • propp-fr (NER + coref)│
└─────────────────┘                         │  • ontologie EduPicto.owx│
        │                                   │  • Mistral (génération)  │
        ▼                                   └──────────────────────────┘
  pictos ARASAAC (CDN)
  static.arasaac.org
```

- **Backend** ([server.py](server.py)) : Flask. Pour chaque mot, cherche un concept
  dans l'ontologie `EduPicto.owx` → renvoie l'`id ARASAAC` + un `type`
  (verbe / propre / commun, pour la **clé de Fitzgerald**).
- **Coréférence** ([coref_bridge.py](coref_bridge.py), [coref_propp.py](coref_propp.py)) :
  `propp-fr` (CamemBERT) clusterise les mentions ; une mémoire dynamique complète
  pour les noms propres que le NER rate.
- **Génération** ([generer_texte.py](generer_texte.py)) : appelle l'API Mistral en
  **limitant le vocabulaire aux concepts de l'ontologie**.
- **Frontend** ([picto_express/](picto_express/)) : application **Flutter**
  (web, Android, iOS, desktop). Les images sont chargées depuis le CDN ARASAAC.

---

## Prérequis

- **Python 3.11** (recommandé : [Miniconda](https://docs.conda.io/en/latest/miniconda.html))
- **Flutter SDK** (stable) — [installation](https://docs.flutter.dev/get-started/install)
- **Clé API Mistral** (pour le bouton « Générer ») — https://console.mistral.ai
- GPU NVIDIA **optionnel** (accélère propp-fr ; fonctionne aussi sur CPU, plus lent)

---

## 1. Backend (serveur Python)

```bash
# Environnement
conda create -n picto python=3.11 -y
conda activate picto

# Dépendances
pip install -r requirements.txt

# Modèles spaCy
python -m spacy download fr_core_news_lg     # serveur
python -m spacy download fr_dep_news_trf     # propp-fr (tokenisation)

# Correctif fastcoref (compat transformers 5.x) — OBLIGATOIRE
python patch_fastcoref.py
```

### Clé Mistral

Le serveur lit la clé dans une variable d'environnement **ou** un fichier
(jamais en dur dans le code) :

```bash
echo 'VOTRE_CLE_MISTRAL' > ~/.mistral_key
# ou : export MISTRAL_API_KEY="VOTRE_CLE_MISTRAL"
```

### Lancer le serveur

```bash
python server.py
```

> ⏳ **Au tout premier lancement**, les modèles de coréférence (~160 Mo, propp-fr +
> LingMess) se téléchargent automatiquement depuis Hugging Face. Patientez jusqu'à
> `Le serveur est opérationnel sur le port 5006.`

Le serveur écoute sur **http://localhost:5006**.

#### Endpoints
| Méthode | Route | Corps | Réponse |
|---|---|---|---|
| POST | `/pictogramiser` | `{"texte": "..."}` | `{"flux_de_lecture": [{mot, picto, type}]}` |
| POST | `/generer` | `{"theme": "..."}` | `{"texte": "...", "flux_de_lecture": [...]}` |
| GET | `/` | — | page de test HTML minimale |

---

## 2. Frontend (application Flutter)

```bash
cd picto_express
flutter pub get
```

### Lancer en web (recommandé pour tester)

```bash
flutter run --release -d web-server --web-port 8090 --web-hostname 0.0.0.0
```

Puis ouvrir **http://localhost:8090**.

> ⚠️ Utiliser `--release` : le mode debug (DDC) rend mal sous Firefox.
> Alternative : `flutter run --release -d chrome`.

### Lancer sur mobile / desktop

```bash
flutter run            # appareil/émulateur connecté
flutter build apk      # Android
```

> 📡 L'app contacte le serveur sur `http://localhost:5006`. Sur un **appareil
> physique**, remplacer `localhost` par l'IP de la machine qui héberge le serveur
> dans [picto_express/lib/main.dart](picto_express/lib/main.dart) (variable d'URL).

---

## Utilisation

1. Démarrer le **serveur Python** (étape 1).
2. Démarrer l'**app Flutter** (étape 2).
3. Dans l'app :
   - **Bibliothèque** → choisir une histoire → pictogrammes générés.
   - **✨ Générer une histoire** → saisir un thème → texte créé par l'IA
     (vocabulaire limité à l'ontologie) puis pictogrammisé.

---

## Notes

- **CPU vs GPU** : tout fonctionne sur CPU. Un GPU réduit fortement le temps
  d'analyse (CamemBERT-large). `spacy.prefer_gpu()` bascule automatiquement.
- **Ontologie** : `EduPicto.owx` (format OWL/XML, éditable avec Protégé). Les
  concepts y sont reliés à des `id ARASAAC` et regroupés par classe.
- **Modèles** : le dossier `AntoineBourgois/` (modèles propp-fr) est ignoré par git
  et recréé automatiquement au premier lancement du serveur.

## Structure

```
server.py            API Flask (pictogramiser + generer)
coref_propp.py       pipeline propp-fr (NER + coréférence + LingMess)
coref_bridge.py      pont coréférence ↔ serveur
generer_texte.py     génération de texte contrainte par l'ontologie (Mistral)
patch_fastcoref.py   correctif compat transformers 5.x
EduPicto.owx         ontologie des concepts → pictogrammes
requirements.txt     dépendances Python
picto_express/       application Flutter (frontend)
```
