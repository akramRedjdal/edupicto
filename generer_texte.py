# -*- coding: utf-8 -*-
"""
Génère un texte de test via l'API Mistral, en limitant le vocabulaire aux
concepts présents dans l'ontologie EduPicto.owx.

Objectif : produire un texte simple (aide à la lecture, enfants autistes) qui
- n'emploie que des concepts pictogrammables (présents dans l'ontologie)
- introduit un personnage nommé puis le reprend par des pronoms (il/elle/ils)
  → exerce la résolution de coréférence du serveur.

CLÉ API (une des deux) :
  export MISTRAL_API_KEY="..."        (variable d'environnement)
  ou bien fichier  ~/.mistral_key     (contenant juste la clé)

USAGE :
  python generer_texte.py                      # thème libre
  python generer_texte.py "une recette simple" # thème imposé
  python generer_texte.py --envoyer            # génère puis envoie au serveur 5006
"""

import os
import re
import sys
import json
import requests

OWX = "EduPicto.owx"
MISTRAL_URL = "https://api.mistral.ai/v1/chat/completions"
MODELE = "ministral-14b-2512"

# Concepts techniques à exclure de la palette (pas des mots affichables)
EXCLURE_PREFIXES = ("contexte_",)
EXCLURE_SUFFIXES = ("_demo", "_metier")
EXCLURE_CLASSES = {"Univers_Cuisine", "Univers_Justice"}

# Étiquettes lisibles par classe d'ontologie
LABELS_CLASSES = {
    "Personne": "Personnages",
    "Action": "Actions (verbes)",
    "Aliment": "Aliments",
    "Lieu": "Lieux",
    "Objet_Ustensile": "Objets / ustensiles",
    "Animal": "Animaux",
    "Vêtement": "Vêtements",
    "Adjectif": "Adjectifs",
    "Temps": "Moments",
    "Durée": "Durées",
    "Couleur": "Couleurs",
    "Adverbe": "Adverbes",
    "Métier": "Métiers",
    "Evenements": "Événements",
    "Famille": "Famille",
    "Forme": "Formes",
    "Bijoux": "Bijoux",
    "Appareil_Chauffage": "Chauffage",
    "Planète": "Planètes",
    "Matériel": "Matériaux",
}


def charger_concepts(chemin=OWX):
    """Extrait {individu: classe} depuis les ClassAssertion de l'ontologie."""
    with open(chemin, "r", encoding="utf-8") as f:
        xml = f.read()
    assertions = re.findall(
        r'<ClassAssertion>\s*<Class IRI="#([^"]+)"/>\s*'
        r'<NamedIndividual IRI="#([^"]+)"/>\s*</ClassAssertion>',
        xml,
    )
    concepts = {}
    for cls, ind in assertions:
        if cls in EXCLURE_CLASSES:
            continue
        if ind.startswith(EXCLURE_PREFIXES) or ind.endswith(EXCLURE_SUFFIXES):
            continue
        concepts[ind] = cls
    return concepts


def lisible(nom):
    """avocat_metier -> 'avocat', arrière_grand_mère -> 'arrière-grand-mère'."""
    return nom.replace("_", " ").strip()


def palette_par_classe(concepts):
    """Regroupe les concepts par classe, en libellés lisibles."""
    groupes = {}
    for ind, cls in concepts.items():
        groupes.setdefault(cls, []).append(lisible(ind))
    for cls in groupes:
        groupes[cls] = sorted(set(groupes[cls]))
    return groupes


def construire_prompt(concepts, theme=None):
    groupes = palette_par_classe(concepts)

    # Ordre d'affichage : personnages et actions d'abord (utiles à la coréf)
    ordre = ["Personne", "Action", "Aliment", "Lieu", "Objet_Ustensile",
             "Animal", "Vêtement", "Adjectif", "Temps", "Durée", "Couleur",
             "Adverbe", "Métier", "Evenements", "Famille", "Forme", "Bijoux",
             "Appareil_Chauffage", "Planète", "Matériel"]

    lignes = []
    for cls in ordre:
        if cls in groupes:
            label = LABELS_CLASSES.get(cls, cls)
            lignes.append(f"- {label} : {', '.join(groupes[cls])}")
    palette = "\n".join(lignes)

    theme_txt = f"\nThème souhaité : {theme}." if theme else ""

    system = (
        "Tu écris des textes très simples pour aider des enfants autistes à lire "
        "avec des pictogrammes. Phrases courtes, présent de l'indicatif, une idée "
        "par phrase."
    )

    user = f"""Écris un court texte (6 à 10 phrases) en français.{theme_txt}

CONTRAINTE STRICTE DE VOCABULAIRE (règle absolue) :
Chaque nom, verbe et adjectif que tu écris DOIT figurer dans la palette ci-dessous.
- Tu peux conjuguer un verbe et accorder un nom/adjectif, mais le mot de base doit
  être dans la liste.
- INTERDIT d'employer un synonyme ou un mot proche s'il n'est pas listé. Si le
  concept que tu veux n'existe pas, CHOISIS-EN un autre DANS la liste.
- Exemples d'erreurs à NE PAS commettre : écrire "poire" alors que seul "pomme"
  est listé ; écrire "enfourner" alors que seuls "placer" et "four" sont listés.
- Seuls les petits mots de liaison sont libres (le, la, un, des, dans, et, avec,
  pour, il, elle, ils, elles, son, sa, ses...).

POUR TESTER LA CORÉFÉRENCE :
- Choisis UN seul personnage de la liste, nomme-le au début.
- Ensuite reprends-le plusieurs fois par un pronom SINGULIER (il ou elle).
- N'utilise "ils"/"elles" QUE si tu as nommé explicitement un groupe ou deux
  personnes avant (sinon évite le pluriel).

PALETTE DE CONCEPTS AUTORISÉS :
{palette}

AVANT DE RÉPONDRE : relis ton texte et remplace tout nom/verbe/adjectif qui ne
serait pas dans la palette par un mot de la palette.

Donne uniquement le texte final, sans titre ni explication."""

    return system, user


def lire_cle():
    cle = os.environ.get("MISTRAL_API_KEY")
    if cle:
        return cle.strip()
    chemin = os.path.expanduser("~/.mistral_key")
    if os.path.exists(chemin):
        with open(chemin) as f:
            return f.read().strip()
    sys.exit(
        "ERREUR: clé Mistral introuvable.\n"
        "  export MISTRAL_API_KEY=\"...\"   ou   echo 'sk-...' > ~/.mistral_key"
    )


def generer(theme=None):
    concepts = charger_concepts()
    system, user = construire_prompt(concepts, theme)
    cle = lire_cle()

    resp = requests.post(
        MISTRAL_URL,
        headers={"Authorization": f"Bearer {cle}",
                 "Content-Type": "application/json"},
        json={
            "model": MODELE,
            "temperature": 0.3,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        },
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"].strip()


def envoyer_au_serveur(texte, url="http://localhost:5006/pictogramiser"):
    r = requests.post(url, json={"texte": texte}, timeout=120)
    r.raise_for_status()
    flux = r.json()["flux_de_lecture"]
    print("\n=== FLUX PICTOS (mot -> id, type) ===")
    for el in flux:
        mot = (el.get("mot") or "").strip()
        if mot:
            print(f"  {mot:20s} -> {el.get('picto')} ({el.get('type')})")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--envoyer"]
    envoyer = "--envoyer" in sys.argv
    theme = args[0] if args else None

    texte = generer(theme)
    print("=== TEXTE GÉNÉRÉ (Mistral, vocabulaire = ontologie) ===\n")
    print(texte)

    if envoyer:
        envoyer_au_serveur(texte)
