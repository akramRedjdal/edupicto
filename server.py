import os
import re
import unicodedata
from flask import Flask, request, jsonify
from flask_cors import CORS
import spacy

import coref_bridge as cb
import generer_texte

app = Flask(__name__)
CORS(app)

# Modèle transformer : POS/lemmatisation plus fiables que fr_core_news_lg
# (ex: "Elle marche" correctement étiqueté VERB), crucial pour la polysémie.
print("Chargement de spaCy (fr_dep_news_trf)")
spacy.prefer_gpu()
nlp = spacy.load("fr_dep_news_trf")

print("Analyse et indexation sémantique du fichier EduPicto.owx...")

# ─── EXTRACTION DES DONNEES POUR L'ONTOLOGIE OWX (.owx) ────────────────
def charger_ontologie_xml(fichier_chemin):
    with open(fichier_chemin, "r", encoding="utf-8") as f:
        xml_str = f.read()

    # Extraction des classes 
    class_assertions = re.findall(r'<ClassAssertion>\s*<Class IRI="#([^"]+)"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*</ClassAssertion>', xml_str)
    ind_classes = {ind: cls for cls, ind in class_assertions}

    # Extraction des chemins de fichiers images locaux (plus besoin mais au cas où)
    chemin_assertions = re.findall(r'<DataPropertyAssertion>\s*<DataProperty IRI="#cheminPicto"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*<Literal[^>]*>([^<]+)</Literal>\s*</DataPropertyAssertion>', xml_str)
    ind_picto = {ind: picto.strip() for ind, picto in chemin_assertions}

    # Extraction des id ARASAAC
    id_assertions = re.findall(r'<AnnotationAssertion>\s*<AnnotationProperty IRI="#arasaac_id"/>\s*<IRI>#([^<]+)</IRI>\s*<Literal[^>]*>([^<]+)</Literal>\s*</AnnotationAssertion>', xml_str)
    ind_id = {ind: aid.strip() for ind, aid in id_assertions}

    # Catégorie grammaticale (POS) :
    #  - déduite de la classe (Action=verbe, Adjectif, Adverbe, sinon nom)
    #  - surchargée si l'ontologie déclare explicitement #categorieGrammaticale
    #    (utile pour la polysémie : ex. "marche" verbe vs "marché" nom)
    def classe_vers_pos(cls):
        return {"Action": "VERB", "Adjectif": "ADJ", "Adverbe": "ADV"}.get(cls, "NOUN")
    pos_assertions = re.findall(r'<DataPropertyAssertion>\s*<DataProperty IRI="#categorieGrammaticale"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*<Literal[^>]*>([^<]+)</Literal>\s*</DataPropertyAssertion>', xml_str)
    ind_pos_explicite = {ind: val.strip().upper() for ind, val in pos_assertions}
    ind_pos = {ind: ind_pos_explicite.get(ind, classe_vers_pos(cls)) for ind, cls in ind_classes.items()}

    # Extraction des liaisons de contextes (Object Properties)
    context_assertions = re.findall(r'<ObjectPropertyAssertion>\s*<ObjectProperty IRI="#aPourContexte"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*</ObjectPropertyAssertion>', xml_str)
    ind_contexts = {}
    for ind, ctx in context_assertions:
        if ind not in ind_contexts:
            ind_contexts[ind] = []
        ind_contexts[ind].append(ctx)

    # Extraction des mots-clés de contexte (Data Properties de Protégé)
    mot_cle_assertions = re.findall(r'<DataPropertyAssertion>\s*<DataProperty IRI="#aPourMotCle"/>\s*<NamedIndividual IRI="#([^"]+)"/>\s*<Literal[^>]*>([^<]+)</Literal>\s*</DataPropertyAssertion>', xml_str)
    ctx_mots = {}
    for ctx, mot in mot_cle_assertions:
        if ctx not in ctx_mots:
            ctx_mots[ctx] = []
        ctx_mots[ctx].append(mot.lower().strip())

    # Consolidation de tous les individus existants
    all_individuals = set()
    all_individuals.update(ind_classes.keys())
    all_individuals.update(ind_picto.keys())
    all_individuals.update(ind_id.keys())
    all_individuals.update(ind_contexts.keys())

    return {
        "classes": ind_classes,
        "pictos": ind_picto,
        "ids": ind_id,
        "contexts": ind_contexts,
        "keywords": ctx_mots,
        "pos": ind_pos,
        "all_individuals": list(all_individuals)
    }

# Chargement de la structure sémantique en mémoire
ONTOLOGY_DATA = charger_ontologie_xml("EduPicto.owx")

# Coréférence avancée (propp_fr + LingMess). Optionnelle : si le chargement
# échoue (pas de GPU, modèles absents...), le serveur garde sa logique de secours.
COREF_AVANCE = False
try:
    print("Chargement des modèles de coréférence (propp_fr)...")
    cb.init(with_lingmess=True)
    COREF_AVANCE = True
    print("Coréférence avancée activée.")
except Exception as e:
    print(f"Coréférence avancée indisponible ({e}). Fallback mémoire ciblée.")

print("Le serveur est opérationnel sur le port 5006.")


def retirer_accents(texte):
    if not texte: return ""
    return "".join(c for c in unicodedata.normalize('NFD', texte) if unicodedata.category(c) != 'Mn').lower().strip()

def obtenir_radical(mot):
    """ Extrait la racine d'un mot ou d'un verbe en coupant les terminaisons courantes """
    m = retirer_accents(mot)
    if m in ["phoque", "phoques"]: return "phoque"
    if m in ["oeuf", "oeufs", "œuf", "œufs"]: return "oeuf"
    if m in ["ingredients", "ingredient"]: return "ingredient"
    
    for suff in ['er', 'ir', 'ons', 'ez', 'ent', 'es', 'e']:
        if m.endswith(suff) and len(m) - len(suff) >= 3:
            return m[:-len(suff)]
    return m

def extraire_id_depuis_individu(ind_name):
    """ extrait l'identifiant numérique Arasaac ou le nom de fichier local (au cas ou) """
    aid = ONTOLOGY_DATA["ids"].get(ind_name)
    if aid:
        return aid
    return ONTOLOGY_DATA["pictos"].get(ind_name)

def chercher_individu_dans_ontologie(mot_brut, lemme, target_idx, tokens):
    if not mot_brut or len(mot_brut.strip()) <= 1: return None
    
    rad_mot = obtenir_radical(mot_brut)
    rad_lem = obtenir_radical(lemme)
    
    candidates = []
    for name in ONTOLOGY_DATA["all_individuals"]:
        rad_ind = obtenir_radical(name)
        if (rad_ind == rad_mot or rad_ind == rad_lem or 
            rad_ind.startswith(rad_mot + "_") or rad_ind.startswith(rad_lem + "_")):
            candidates.append(name)
            
    if not candidates: return None

    # DÉSAMBIGUÏSATION PAR CATÉGORIE GRAMMATICALE (POS)
    # Ex: "je marche jusqu'au marché" -> "marche" (VERB) = marcher,
    #     "marché" (NOUN) = le marché. On filtre les candidats selon le POS
    #     que spaCy donne au token courant.
    pos_groupe = None
    if 0 <= target_idx < len(tokens):
        pos_groupe = {"VERB": "VERB", "AUX": "VERB", "NOUN": "NOUN",
                      "PROPN": "NOUN", "ADJ": "ADJ", "ADV": "ADV"}.get(tokens[target_idx].pos_)
    if pos_groupe and len(candidates) > 1:
        filtres = [c for c in candidates if ONTOLOGY_DATA["pos"].get(c) == pos_groupe]
        if filtres:  # fallback : si le filtre vide tout, on garde les candidats d'origine
            candidates = filtres

    if len(candidates) == 1:
        return candidates[0]

    # PTIT ALGORITHME DE SCORING (PONDÉRÉ PAR LA DISTANCE)
    scores_contextes = {ctx: 0.0 for ctx in ONTOLOGY_DATA["keywords"]}
    
    for idx, t in enumerate(tokens):
        word = retirer_accents(t.text)
        distance = abs(idx - target_idx)
        poids = 1.0 / (1.0 + distance)
        
        for ctx, mots_cles in ONTOLOGY_DATA["keywords"].items():
            if word in mots_cles:
                scores_contextes[ctx] += poids
            
    best_candidate = candidates[0]
    max_score = -1.0
    
    for cand in candidates:
        score_cand = 0.0
        ctx_list = ONTOLOGY_DATA["contexts"].get(cand, [])
        for ctx in ctx_list:
            score_cand += scores_contextes.get(ctx, 0.0)
            
        if score_cand > max_score:
            max_score = score_cand
            best_candidate = cand
            
    return best_candidate

def detecter_contexte_automatique(doc):
    txt = retirer_accents(doc.text)
    if "salade" in txt or "tarte" in txt or "pomme" in txt or "avocat" in txt: 
        return "contexte_cuisine"


@app.route('/')
def index():
    # Sert le frontend (saisie texte + affichage des pictogrammes)
    with open("index.html", encoding="utf-8") as f:
        return f.read()


def analyser_texte(texte_brut):
    """Cœur du pipeline : texte brut -> liste d'éléments {mot, picto, type}."""
    texte_propre = texte_brut.replace("après-midi", "après_midi")
    doc = nlp(texte_propre)

    # COREF AVANCÉE : propp_fr clusterise les pronoms et leurs têtes nominales.
    # pronom_to_cluster : {offset_char_pronom -> id_cluster}
    # cluster_rep       : {id_cluster -> {head_word, text, cat}} (tête nominale, si présente)
    if COREF_AVANCE:
        pronom_to_cluster, cluster_rep = cb.resoudre(texte_propre)
    else:
        pronom_to_cluster, cluster_rep = {}, {}

    # MEMOIRE COREF CIBLÉE (fallback hardcodé, conservé en ultime recours)
    memoire_coref = {"il": None, "ils": None, "elle": None, "elles": None}

    # MEMOIRE DYNAMIQUE : dernier individu de classe Personne rencontré.
    # Capte les noms propres que le NER propp_fr rate (ex: "Léo") via l'ontologie.
    dernier_personne = None
    
    liste_elements_flux = []
    tokens = list(doc)
    i = 0
    
    mots_interdits = [
        "on", "tu", "je", "nous", "vous",
        "dans", "le", "la", "les", "un", "une", "des", "du", "de", "pour", "avec", "et", "mais"
    ]
    
    while i < len(tokens):
        token = tokens[i]
        if token.is_space:
            i += 1
            continue

        # Interception des numéros de liste (1., 2., etc.)
        if token.is_digit and i + 1 < len(tokens) and tokens[i+1].text in [".", ")", "-"]:
            liste_elements_flux.append({"mot": "", "picto": None, "type": None})
            i += 2
            continue
            
        if token.is_digit and len(tokens) == 1:
            liste_elements_flux.append({"mot": "", "picto": None, "type": None})
            i += 1
            continue

        mot_affichage = token.text_with_ws
        lemme = token.lemma_.lower().strip()
        phrase_tokens = list(token.sent)

        # INTERCEPTION ET RÈGLES DE SUBSTUTITION DES PRONOMS CIBLÉS
        pronom_normalise = token.text.lower().strip()
        if pronom_normalise in ["il", "ils", "elle", "elles"]:
            
            # Détection et exclusion immédiate des tournures impersonnelles (ex: il fait froid, il y a)
            est_impersonnel = False
            if pronom_normalise == "il" and i + 1 < len(tokens):
                suivant = tokens[i+1].lemma_.lower().strip()
                if suivant in ["y", "falloir", "faut", "pleuvoir", "pleut"]:
                    est_impersonnel = True
                elif suivant in ["faire", "fait"]:
                    texte_phrase = retirer_accents(token.sent.text)
                    if "froid" in texte_phrase or "chaud" in texte_phrase or "beau" in texte_phrase:
                        est_impersonnel = True
            
            if est_impersonnel:
                # On laisse le picto vide par exemple pour la meteo
                liste_elements_flux.append({"mot": mot_affichage, "picto": None, "type": None})
                i += 1
                continue
                
            # Résolution coréférence : cluster propp_fr > mémoire dynamique > hardcodé
            ind_substitut = None

            cid = pronom_to_cluster.get(token.idx)
            if cid is not None:
                rep = cluster_rep.get(cid)
                if rep:
                    rep_word = rep.get("head_word") or rep.get("text")
                    if rep_word:
                        ind_substitut = chercher_individu_dans_ontologie(rep_word, rep_word, i, tokens)

            if ind_substitut is None and pronom_normalise in ("il", "elle"):
                # Antécédent singulier raté par le NER (ex: Léo) → dernier Personne vu.
                # Volontairement PAS appliqué à ils/elles : un pronom pluriel
                # exigerait un picto "plusieurs personnes" que l'on n'a pas.
                ind_substitut = dernier_personne

            if ind_substitut is None:
                ind_substitut = memoire_coref.get(pronom_normalise)  # ultime secours

            if ind_substitut:
                id_arasaac = extraire_id_depuis_individu(ind_substitut)
                cls_name = ONTOLOGY_DATA["classes"].get(ind_substitut, "")
                if cls_name == "Action": type_mot = "verbe"
                elif cls_name == "Personne": type_mot = "propre"
                else: type_mot = "commun"

                liste_elements_flux.append({"mot": mot_affichage, "picto": id_arasaac, "type": type_mot})
                i += 1
                continue

        # Traitement des élisions (l'œuf, l'avocat...)
        if (token.text.endswith("'") or token.text.endswith("’")) and i + 1 < len(tokens):
            next_token = tokens[i+1]
            mot_affichage = token.text + next_token.text_with_ws
            lemme_elide = next_token.lemma_.lower().strip()
            
            id_arasaac = None
            type_mot = None
            if not next_token.is_punct and lemme_elide not in mots_interdits and next_token.text.lower() != "mais":
                ind_trouve = chercher_individu_dans_ontologie(next_token.text, next_token.lemma_, next_token.i, tokens)
                if ind_trouve: 
                    id_arasaac = extraire_id_depuis_individu(ind_trouve)
                    cls_name = ONTOLOGY_DATA["classes"].get(ind_trouve, "")
                    if cls_name == "Action": type_mot = "verbe"
                    elif cls_name == "Personne": type_mot = "propre"
                    else: type_mot = "commun"
                    
                    # Mémoire dynamique : tout individu Personne devient l'antécédent courant
                    if cls_name == "Personne":
                        dernier_personne = ind_trouve

                    # Enregistrement exclusif et ciblé dans la mémoire de coréférence
                    nom_nettoye = retirer_accents(ind_trouve)
                    if ind_trouve == "Léo": memoire_coref["il"] = "Léo"
                    elif nom_nettoye in ["mala", "poline"]: memoire_coref["elles"] = ind_trouve
                    elif nom_nettoye == "maison": memoire_coref["elle"] = "maison"
                    elif nom_nettoye in ["legume", "légume"]: memoire_coref["ils"] = "légume"
                    elif nom_nettoye in ["inuit", "esquimau"]: memoire_coref["ils"] = ind_trouve

            liste_elements_flux.append({"mot": mot_affichage, "picto": id_arasaac, "type": type_mot})
            i += 2
            continue
            
        if i + 1 < len(tokens) and tokens[i+1].is_punct and tokens[i+1].text in [".", ",", ";", "!", "?", ":"]:
            mot_affichage = mot_affichage.rstrip() + tokens[i+1].text_with_ws
            i += 1
            
        id_arasaac = None
        type_mot = None
        
        if not token.is_punct and lemme not in mots_interdits and token.text.lower() != "mais":
            # token.i = vrai index du token (i a pu être incrémenté par la fusion ponctuation)
            ind_trouve = chercher_individu_dans_ontologie(token.text, token.lemma_, token.i, tokens)
            if ind_trouve: 
                id_arasaac = extraire_id_depuis_individu(ind_trouve)
                cls_name = ONTOLOGY_DATA["classes"].get(ind_trouve, "")
                if cls_name == "Action": type_mot = "verbe"
                elif cls_name == "Personne": type_mot = "propre"
                else: type_mot = "commun"
                
                # Mémoire dynamique : tout individu Personne devient l'antécédent courant
                if cls_name == "Personne":
                    dernier_personne = ind_trouve

                # Enregistrement exclusif et ciblé dans la mémoire de coréférence manuelle
                nom_nettoye = retirer_accents(ind_trouve)
                if ind_trouve == "Léo": memoire_coref["il"] = "Léo"
                elif nom_nettoye in ["mala", "poline"]: memoire_coref["elles"] = ind_trouve
                elif nom_nettoye == "maison": memoire_coref["elle"] = "maison"
                elif nom_nettoye in ["legume", "légume"]: memoire_coref["ils"] = "légume"
                elif nom_nettoye in ["inuit", "esquimau"]: memoire_coref["ils"] = ind_trouve

        liste_elements_flux.append({"mot": mot_affichage, "picto": id_arasaac, "type": type_mot})
        i += 1

    return liste_elements_flux


@app.route('/pictogramiser', methods=['POST'])
def pictogramiser_texte_integral():
    texte_brut = (request.json or {}).get("texte", "")
    return jsonify({"flux_de_lecture": analyser_texte(texte_brut)})


@app.route('/generer', methods=['POST'])
def generer_route():
    """Génère un texte via Mistral (vocabulaire = ontologie) puis le pictogramise.
    La clé Mistral reste côté serveur (jamais exposée au client Flutter)."""
    theme = (request.json or {}).get("theme")
    try:
        texte = generer_texte.generer(theme)
    except SystemExit as e:
        # clé Mistral absente
        return jsonify({"erreur": str(e)}), 503
    except Exception as e:
        return jsonify({"erreur": f"Génération impossible : {e}"}), 502
    return jsonify({"texte": texte, "flux_de_lecture": analyser_texte(texte)})


if __name__ == '__main__':
    # PORT fourni par l'hébergeur (HF Spaces = 7860), 5006 en local par défaut.
    port = int(os.environ.get("PORT", 5006))
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)