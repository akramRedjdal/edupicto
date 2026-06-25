# -*- coding: utf-8 -*-


import spacy
import torch
from spacy import displacy

import spacy_curated_transformers

from propp_fr import (
    generate_tokens_df,
    load_mentions_detection_model,
    load_coreference_resolution_model,
    load_tokenizer_and_embedding_model,
    get_embedding_tensor_from_tokens_df,
    generate_entities_df,
    add_features_to_entities,
    perform_coreference
)

# -----------------------------
# MODELS
# -----------------------------

NER_MODEL = "AntoineBourgois/propp-fr_NER_camembert-large_FAC_GPE_LOC_PER_TIME_VEH"
COREF_MODEL = "AntoineBourgois/propp-fr_coreference-resolution_camembert-large_PER"

PALETTE = [
    "#f4a261", "#2a9d8f", "#e76f51", "#457b9d", "#8ecae6",
    "#e9c46a", "#06d6a0", "#ef476f", "#a8dadc", "#264653"
]


# -----------------------------
# CORÉFÉRENCE RULE-BASED (non-PER)
# -----------------------------

def rule_based_coref_for_non_per(entities_df, coref_id_start):
    """
    Assigne des COREF IDs aux entités non-PER par correspondance de texte (par type).
    Les entités de même texte (normalisé) et de même type sont regroupées dans le même cluster.
    """
    non_per_cats = [c for c in entities_df["cat"].dropna().unique() if c != "PER"]
    next_id = coref_id_start

    for cat in non_per_cats:
        cat_mask = entities_df["cat"] == cat
        cat_entities = entities_df[cat_mask]

        text_to_ids = {}
        for idx, row in cat_entities.iterrows():
            key = str(row.get("text", "")).lower().strip()
            if not key:
                key = f"__unknown_{idx}__"
            text_to_ids.setdefault(key, []).append(idx)

        for ids in text_to_ids.values():
            entities_df.loc[ids, "COREF"] = next_id
            next_id += 1

    return entities_df


# -----------------------------
# FASTCOREF (LingMess)
# -----------------------------

def load_lingmess_model(device="cuda:0"):
    from fastcoref import LingMessCoref
    return LingMessCoref(device=device)


def merge_fastcoref(entities_df, tokens_df, text, lingmess_model):
    """
    Enrichit les COREF via LingMess (coréférences inter-types et non-PER).
    Clusters purement PER : propp-fr garde la priorité.
    Clusters non-PER ou mixtes : LingMess fusionne les IDs.
    Entités partageant le même COREF ID (même cross-type) → même couleur.
    """
    preds = lingmess_model.predict(texts=[text])
    lingmess_clusters = preds[0].get_clusters(as_strings=False)

    b2c = build_byte_to_char_map(text)
    entity_indices = list(entities_df.index)
    entity_char_spans = []
    for _, row in entities_df.iterrows():
        st = int(row["start_token"])
        et = int(row["end_token"])
        b_start = int(tokens_df.loc[
            tokens_df["token_ID_within_document"] == st, "byte_onset"
        ].values[0])
        b_end = int(tokens_df.loc[
            tokens_df["token_ID_within_document"] == et, "byte_offset"
        ].values[0])
        entity_char_spans.append((b2c.get(b_start, b_start), b2c.get(b_end, b_end)))

    def find_entity_for_span(c_start, c_end):
        best_idx, best_overlap = None, 0
        for i, (es, ee) in enumerate(entity_char_spans):
            overlap = min(c_end, ee) - max(c_start, es)
            if overlap > best_overlap:
                best_overlap = overlap
                best_idx = i
        return best_idx if best_overlap > 0 else None

    next_id = int(entities_df["COREF"].dropna().max()) + 1 if entities_df["COREF"].notna().any() else 0

    for cluster in lingmess_clusters:
        matched = []
        for c_start, c_end in cluster:
            local_idx = find_entity_for_span(c_start, c_end)
            if local_idx is not None:
                df_idx = entity_indices[local_idx]
                if df_idx not in matched:
                    matched.append(df_idx)

        if len(matched) < 2:
            continue

        cats = entities_df.loc[matched, "cat"].tolist()
        unique_cats = set(cats)

        # propp-fr gère mieux les clusters PER purs
        if unique_cats == {"PER"}:
            continue

        # LingMess (entraîné sur l'anglais) génère trop de faux positifs
        # cross-type sur le français → on n'accepte que les fusions intra-type non-PER
        if len(unique_cats) > 1:
            continue

        existing = entities_df.loc[matched, "COREF"].dropna()
        target_id = int(existing.iloc[0]) if len(existing) > 0 else next_id
        if len(existing) == 0:
            next_id += 1
        entities_df.loc[matched, "COREF"] = target_id

    return entities_df


# -----------------------------
# CHARGEMENT DES MODÈLES (une seule fois)
# -----------------------------

def load_all_models(with_lingmess=True, device="cuda:0"):
    """
    Charge tous les modèles une seule fois. Réutilisable pour un serveur :
    évite de recharger CamemBERT-large à chaque requête.
    """
    spacy.prefer_gpu()
    nlp = spacy.load("fr_dep_news_trf")
    mentions_model = load_mentions_detection_model(NER_MODEL, force_download=False)
    base = mentions_model["base_model_name"]
    tokenizer, embedding_model = load_tokenizer_and_embedding_model(base)
    coref_model = load_coreference_resolution_model(COREF_MODEL, force_download=False)

    lingmess_model = None
    if with_lingmess:
        lingmess_model = load_lingmess_model(device=device)

    return {
        "nlp": nlp,
        "mentions_model": mentions_model,
        "base": base,
        "tokenizer": tokenizer,
        "embedding_model": embedding_model,
        "coref_model": coref_model,
        "lingmess_model": lingmess_model,
    }


# -----------------------------
# PIPELINE PROPP-FR
# -----------------------------

def run_pipeline(text, lingmess_model=None, models=None):

    print("GPU:", torch.cuda.is_available())

    # Réutilise les modèles préchargés si fournis, sinon charge à la volée
    if models is None:
        models = load_all_models(with_lingmess=False)
    if lingmess_model is None:
        lingmess_model = models.get("lingmess_model")

    nlp = models["nlp"]
    mentions_model = models["mentions_model"]
    base = models["base"]
    tokenizer = models["tokenizer"]
    embedding_model = models["embedding_model"]
    coref_model = models["coref_model"]

    # TOKENS
    tokens_df = generate_tokens_df(text, nlp)

    # NER
    emb = get_embedding_tensor_from_tokens_df(
        text,
        tokens_df,
        tokenizer,
        embedding_model,
        mini_batch_size=32,
        subword_pooling_strategy=mentions_model["subword_pooling_strategy"]
    )

    entities_df = generate_entities_df(tokens_df, emb, mentions_model, batch_size=32)
    entities_df = add_features_to_entities(entities_df, tokens_df)

    # COREF ML (PER uniquement — seul modèle disponible)
    if coref_model["base_model_name"] != base:
        tokenizer, embedding_model = load_tokenizer_and_embedding_model(
            coref_model["base_model_name"]
        )
        emb = get_embedding_tensor_from_tokens_df(text, tokens_df, tokenizer, embedding_model)

    entities_df = perform_coreference(
        entities_df=entities_df,
        tokens_embedding_tensor=emb,
        coreference_resolution_model=coref_model,
        batch_size=50000,
        propagate_coref=True,
        rule_based_postprocess=False
    )

    # COREF rule-based pour FAC, GPE, LOC, TIME, VEH (groupement par texte identique)
    next_id = int(entities_df["COREF"].dropna().max()) + 1 if entities_df["COREF"].notna().any() else 0
    entities_df = rule_based_coref_for_non_per(entities_df, next_id)

    # COREF LingMess : coréférences inter-types et non-PER (optionnel)
    if lingmess_model is not None:
        print("Fusion LingMess...")
        entities_df = merge_fastcoref(entities_df, tokens_df, text, lingmess_model)

    return tokens_df, entities_df


# -----------------------------
# CONVERSION BYTE → CHAR
# -----------------------------

def build_byte_to_char_map(text):
    table = {}
    b = 0
    for i, ch in enumerate(text):
        table[b] = i
        b += len(ch.encode("utf-8"))
    table[b] = len(text)
    return table


# -----------------------------
# DISPLACY BUILDER
# -----------------------------

def build_displacy_entities(text, tokens_df, entities_df):
    ents = []
    for _, row in entities_df.iterrows():
        if row["COREF"] is None:
            continue

        start_token = int(row["start_token"])
        end_token   = int(row["end_token"])
        c_start = int(tokens_df.loc[
            tokens_df["token_ID_within_document"] == start_token, "byte_onset"
        ].values[0])
        c_end = int(tokens_df.loc[
            tokens_df["token_ID_within_document"] == end_token, "byte_offset"
        ].values[0])

        cat = str(row.get("cat", "ENT"))
        ents.append({
            "start": c_start,
            "end":   c_end,
            "label": f"{cat}_{int(row['COREF'])}",
        })

    ents.sort(key=lambda e: e["start"])
    return ents


# -----------------------------
# COLORS
# -----------------------------

def build_colors(entities_df):
    # Une couleur par COREF ID — partagée entre tous les types du même cluster
    cores = sorted(entities_df["COREF"].dropna().astype(int).unique())
    coref_to_color = {cid: PALETTE[i % len(PALETTE)] for i, cid in enumerate(cores)}
    valid = entities_df[entities_df["COREF"].notna()][["COREF", "cat"]].drop_duplicates()
    return {
        f"{row['cat']}_{int(row['COREF'])}": coref_to_color[int(row['COREF'])]
        for _, row in valid.iterrows()
    }


# -----------------------------
# VISUALISATION HTML
# -----------------------------

def export_html(text, tokens_df, entities_df, output="coref.html"):

    ents = build_displacy_entities(text, tokens_df, entities_df)
    colors = build_colors(entities_df)

    html = displacy.render(
        {
            "text": text,
            "ents": ents,
            "title": "Propp-fr Coreference (corrected)"
        },
        style="ent",
        manual=True,
        options={"colors": colors},
        page=True
    )

    with open(output, "w", encoding="utf-8") as f:
        f.write(html)

    print("✔ HTML généré :", output)


# -----------------------------
#  DEMO
# -----------------------------

if __name__ == "__main__":
    texte = """Léo est dans la cuisine. Dans l'après-midi, il a des invités.
Il décide de faire une salade composée pour ses invités.
Sur une table, il prépare les ingrédients et le matériel.
Il égoutte le maïs avec la passoire.
Il lave, il épluche et il râpe des carottes.
Il coupe le gruyère en petits cubes.
Il retire la peau et le noyau de l'avocat.
Il coupe l'avocat en fines lamelles.
Il fait ensuite une vinaigrette avec l'huile, le vinaigre, le sel et le poivre.
Il verse la vinaigrette dans un saladier avec les carottes, le maïs, l'avocat et le gruyère.
Il mélange.
La salade composée est prête."""

    lingmess = load_lingmess_model(device="cuda:0")
    tokens_df, entities_df = run_pipeline(texte, lingmess_model=lingmess)

    export_html(texte, tokens_df, entities_df)

    print(entities_df[["text", "cat", "prop", "COREF"]].to_string())