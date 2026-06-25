# -*- coding: utf-8 -*-
"""
Correctif de compatibilité fastcoref ↔ transformers >= 5.x.

fastcoref 2.1.6 a été écrit pour transformers 4.x. Sous transformers 5.x,
le chargement de LingMess/FCoref échoue pour deux raisons :

  1. Longformer ne supporte pas l'attention SDPA → il faut forcer
     `attn_implementation="eager"` à la construction du modèle de base.
  2. transformers 5.x attend un attribut de classe `all_tied_weights_keys`
     que fastcoref ne définit pas.

Ce script applique les deux correctifs DIRECTEMENT dans les fichiers
installés de fastcoref. Il est idempotent : relançable sans risque.

Usage :
    python patch_fastcoref.py
"""

import os
import re
import fastcoref

CIBLES = ["coref_models/modeling_lingmess.py",
          "coref_models/modeling_fcoref.py"]

CLASSES = {
    "modeling_lingmess.py": "LingMessModel",
    "modeling_fcoref.py": "FCorefModel",
}


def patch_fichier(chemin):
    nom = os.path.basename(chemin)
    with open(chemin, "r", encoding="utf-8") as f:
        src = f.read()
    original = src

    # 1) forcer attn_implementation="eager"
    if 'AutoModel.from_config(config, attn_implementation="eager")' not in src:
        src = src.replace(
            "AutoModel.from_config(config)",
            'AutoModel.from_config(config, attn_implementation="eager")',
        )

    # 2) ajouter l'attribut de classe all_tied_weights_keys = {}
    classe = CLASSES[nom]
    if "all_tied_weights_keys" not in src:
        src = re.sub(
            rf"(class {classe}\([^)]*\):\n)(\s+def __init__)",
            rf"\1    all_tied_weights_keys = {{}}  # compat transformers>=5.x\n\n\2",
            src,
            count=1,
        )

    if src != original:
        with open(chemin, "w", encoding="utf-8") as f:
            f.write(src)
        return "patché"
    return "déjà OK"


def main():
    base = os.path.dirname(fastcoref.__file__)
    print(f"fastcoref trouvé : {base}")
    for rel in CIBLES:
        chemin = os.path.join(base, rel)
        if not os.path.exists(chemin):
            print(f"  ⚠ introuvable : {rel}")
            continue
        etat = patch_fichier(chemin)
        print(f"  {rel} : {etat}")
    print("Correctif terminé.")


if __name__ == "__main__":
    main()
