# Backend EduPicto — image pour Hugging Face Spaces (SDK Docker, CPU)
FROM python:3.11-slim

# Dépendances système minimales
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl && rm -rf /var/lib/apt/lists/*

# Utilisateur non-root (requis par HF Spaces)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    PORT=7860 \
    HF_HOME=/home/user/.cache/huggingface \
    TRANSFORMERS_CACHE=/home/user/.cache/huggingface

WORKDIR /home/user/app

# 1) PyTorch CPU (évite le téléchargement des paquets CUDA, inutiles sur HF CPU)
RUN pip install --no-cache-dir --user torch==2.12.1 \
    --index-url https://download.pytorch.org/whl/cpu

# 2) Dépendances Python
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# 3) Modèle spaCy transformer (POS/lemmatisation fiables)
RUN python -m spacy download fr_dep_news_trf

# 4) Code
COPY --chown=user . .

# 5) Correctif fastcoref (compat transformers 5.x)
RUN python patch_fastcoref.py

# Les modèles propp-fr (AntoineBourgois/) et LingMess se téléchargent au
# premier démarrage depuis Hugging Face (cold start ~1-2 min).
EXPOSE 7860
CMD ["python", "server.py"]
