# Déploiement — site accessible en ligne

Architecture : **backend** (Python/Flask + modèles) sur **Hugging Face Spaces**,
**frontend** (Flutter web) sur **GitHub Pages**.

---

## A. Backend → Hugging Face Spaces (gratuit, CPU)

### 1. Créer le Space
- Compte sur https://huggingface.co
- New → **Space** → SDK = **Docker** → (CPU basic, gratuit) → nom ex. `edupicto-api`.

### 2. Pousser le backend dans le Space
Le Space est un dépôt git. On y pousse uniquement le backend (le `.dockerignore`
exclut déjà le frontend, les modèles, etc.).

```bash
# cloner le Space créé
git clone https://huggingface.co/spaces/<user>/edupicto-api
cd edupicto-api

# copier les fichiers backend depuis le projet
cp /home/akram/Bureau/Suivis/Projet_Picto/{Dockerfile,.dockerignore,requirements.txt,patch_fastcoref.py} .
cp /home/akram/Bureau/Suivis/Projet_Picto/{server.py,coref_propp.py,coref_bridge.py,generer_texte.py,EduPicto.owx} .
```

### 3. Ajouter l'en-tête HF au README du Space
Créer un `README.md` dans le Space **commençant par** ce bloc YAML :

```
---
title: EduPicto API
emoji: 🧩
colorFrom: orange
colorTo: pink
sdk: docker
app_port: 7860
---

Backend EduPicto (pictogrammisation + coréférence + génération).
```

### 4. Clé Mistral en secret
Dans le Space → **Settings → Variables and secrets** → New secret :
`MISTRAL_API_KEY = <ta clé>`  (jamais dans le code).

### 5. Pousser
```bash
git add -A && git commit -m "Backend EduPicto" && git push
```
Le Space build l'image puis démarre. **Cold start ~1-2 min** (téléchargement des
modèles propp-fr + LingMess). URL finale :
`https://<user>-edupicto-api.hf.space`

Test :
```bash
curl -X POST https://<user>-edupicto-api.hf.space/pictogramiser \
  -H "Content-Type: application/json" -d '{"texte":"Léo coupe une pomme."}'
```

---

## B. Frontend → GitHub Pages

### 1. Build web pointant vers le backend déployé
```bash
cd /home/akram/Bureau/Suivis/Projet_Picto/picto_express
flutter build web --release \
  --dart-define=SERVER_URL=https://<user>-edupicto-api.hf.space \
  --base-href /edupicto/
```
> `--base-href /edupicto/` si la page sera servie sous `…github.io/edupicto/`.
> (À adapter au nom du dépôt.)

### 2. Publier le dossier `build/web` sur la branche `gh-pages`
```bash
cd /home/akram/Bureau/Suivis/Projet_Picto
git subtree push --prefix picto_express/build/web origin gh-pages
# (si build/web est gitignoré, voir variante ci-dessous)
```

Variante simple (sans subtree) :
```bash
cd picto_express/build/web
git init && git add -A && git commit -m "deploy web"
git branch -M gh-pages
git remote add origin https://github.com/akramRedjdal/edupicto.git
git push -f origin gh-pages
```

### 3. Activer Pages
GitHub → repo → Settings → **Pages** → Source = branche `gh-pages` → `/root`.
Site : `https://akramRedjdal.github.io/edupicto/`

---

## Notes / limites

- **CPU lent** : ~15-30 s par texte sur HF Spaces gratuit (pas de GPU). Pour de la
  vitesse, passer le Space en GPU (payant) ou utiliser un VPS/cloud GPU.
- **Cold start** : le Space s'endort après inactivité (gratuit) → 1er appel lent.
- **HTTPS** : HF Spaces et GitHub Pages sont en https → pas de blocage *mixed content*.
- **CORS** : déjà activé côté serveur (`CORS(app)`).
- **Clé Mistral** : reste un secret côté serveur, jamais exposée au navigateur.
- **Mémoire** : ~4-6 Go en CPU (CamemBERT-large + trf + LingMess) → tient dans les
  16 Go du Space gratuit.
