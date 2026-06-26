---
title: EduPicto API
emoji: 🧩
colorFrom: yellow
colorTo: pink
sdk: docker
app_port: 7860
pinned: false
---

# EduPicto — Backend

API de pictogrammisation pour l'aide à la lecture (enfants autistes).

Transforme un texte en pictogrammes ARASAAC via une ontologie de concepts,
avec résolution de coréférence (propp-fr) et génération de texte contrainte
(API Mistral).

## Endpoints
- `POST /pictogramiser` — `{"texte": "..."}` → `{"flux_de_lecture": [...]}`
- `POST /generer` — `{"theme": "..."}` → `{"texte": "...", "flux_de_lecture": [...]}`

Frontend (Flutter web) hébergé séparément.

Projet ESIEE Paris.
