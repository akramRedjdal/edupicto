# -*- coding: utf-8 -*-
"""
Pont propp_fr → server.py

Fournit une résolution de coréférence générique pour remplacer le dict
`memoire_coref` hardcodé du serveur.

propp_fr (CamemBERT) clusterise les mentions (tous les "il" d'un même
personnage ensemble, les noms communs coréférents, etc.). Le serveur, qui
possède l'ontologie, mappe ensuite chaque cluster vers un individu.

Limite connue : le modèle NER propp_fr rate souvent les noms propres
courts dans le registre instructionnel (recette, consignes). Le serveur
complète donc avec une mémoire dynamique "dernier individu Personne vu"
quand un cluster de pronoms n'a aucune tête nominale.
"""

import coref_propp as cp

_MODELS = None


def init(with_lingmess=True, device="cuda:0"):
    """Charge les modèles une seule fois (réutilisé entre requêtes)."""
    global _MODELS
    if _MODELS is None:
        _MODELS = cp.load_all_models(with_lingmess=with_lingmess, device=device)
    return _MODELS


def _char_span(row, tokens_df, b2c):
    """Span caractères (start, end) d'une entité via byte offsets de propp_fr."""
    st = int(row["start_token"])
    et = int(row["end_token"])
    b_start = int(tokens_df.loc[
        tokens_df["token_ID_within_document"] == st, "byte_onset"
    ].values[0])
    b_end = int(tokens_df.loc[
        tokens_df["token_ID_within_document"] == et, "byte_offset"
    ].values[0])
    return b2c.get(b_start, b_start), b2c.get(b_end, b_end)


def resoudre(texte):
    """
    Lance propp_fr sur le texte et renvoie deux structures alignées en
    offsets caractères (mêmes positions que spaCy côté serveur) :

      pronom_to_cluster : { char_start_pronom : cluster_id }
      cluster_rep       : { cluster_id : { "head_word", "text", "cat" } }
                          tête nominale représentative du cluster (None si
                          le cluster ne contient que des pronoms)

    Renvoie ({}, {}) si propp_fr échoue ou trouve trop peu de mentions
    (le serveur bascule alors sur sa logique de secours).
    """
    models = init()
    try:
        tokens_df, entities_df = cp.run_pipeline(texte, models=models)
    except Exception as e:
        print(f"[coref_bridge] propp_fr indisponible, fallback serveur : {e}")
        return {}, {}

    if entities_df is None or len(entities_df) == 0:
        return {}, {}

    b2c = cp.build_byte_to_char_map(texte)

    pronom_to_cluster = {}
    # mentions nominales par cluster, gardées par ordre d'apparition
    cluster_noms = {}

    for _, row in entities_df.iterrows():
        coref = row.get("COREF")
        if coref is None:
            continue
        cid = int(coref)
        c_start, c_end = _char_span(row, tokens_df, b2c)
        prop = str(row.get("prop", ""))

        if prop == "PRON":
            pronom_to_cluster[c_start] = cid
        else:
            cluster_noms.setdefault(cid, []).append({
                "char_start": c_start,
                "head_word": str(row.get("head_word", "")),
                "text": str(row.get("text", "")),
                "cat": str(row.get("cat", "")),
            })

    # Représentant = première mention nominale du cluster (ordre du texte)
    cluster_rep = {}
    for cid, noms in cluster_noms.items():
        noms.sort(key=lambda n: n["char_start"])
        first = noms[0]
        cluster_rep[cid] = {
            "head_word": first["head_word"],
            "text": first["text"],
            "cat": first["cat"],
        }

    return pronom_to_cluster, cluster_rep
