"""
Analyse de sentiment pour les commentaires / messages des réseaux sociaux.

Utilise une bibliothèque dédiée (transformers + modèle Hugging Face
pré-entraîné), et NON un prompt LLM comme dans le reste du projet.
Modèle : cardiffnlp/twitter-xlm-roberta-base-sentiment
  - multilingue (FR / EN / AR / ES / ... )
  - entraîné spécifiquement sur des posts de réseaux sociaux (tweets)
  - 3 classes : negative / neutral / positive
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from transformers import pipeline


DEFAULT_MODEL_NAME = "cardiffnlp/twitter-xlm-roberta-base-sentiment"

# Certaines versions du modèle renvoient des labels génériques (LABEL_0, ...)
# au lieu de "negative"/"neutral"/"positive". On normalise dans tous les cas.
_LABEL_MAP = {
    "negative": "NEGATIVE",
    "neutral": "NEUTRAL",
    "positive": "POSITIVE",
    "label_0": "NEGATIVE",
    "label_1": "NEUTRAL",
    "label_2": "POSITIVE",
}


@dataclass
class SentimentResult:
    text: str
    label: str                      # NEGATIVE | NEUTRAL | POSITIVE
    score: float                    # confiance du label retenu (0-1)
    raw_scores: dict = field(default_factory=dict)  # toutes les probabilités


class SentimentAnalyzer:
    """
    Wrapper autour d'un pipeline Hugging Face pour l'analyse de sentiment.

    Le modèle est chargé une seule fois à l'initialisation (téléchargé et
    mis en cache localement au premier lancement, ~1 Go).
    """

    def __init__(self, model_name: str = DEFAULT_MODEL_NAME):
        self.model_name = model_name
        # top_k=None => retourne le score de CHAQUE classe, pas juste la meilleure
        self._pipe = pipeline(
            task="sentiment-analysis",
            model=model_name,
            tokenizer=model_name,
            top_k=None,
        )

    def analyze(self, text: str) -> SentimentResult:
        """
        Analyse le sentiment d'un texte unique.

        Args:
            text: le commentaire / message à analyser

        Returns:
            SentimentResult avec le label dominant et le détail des scores
        """
        cleaned = (text or "").strip()
        if not cleaned:
            return SentimentResult(text=cleaned, label="NEUTRAL", score=0.0, raw_scores={})

        # Les modèles transformer ont une limite de tokens ; on tronque par sécurité
        truncated = cleaned[:1000]

        outputs = self._pipe(truncated)[0]  # liste de {"label": ..., "score": ...}
        raw_scores = {o["label"].lower(): round(o["score"], 4) for o in outputs}
        best = max(outputs, key=lambda o: o["score"])
        label = _LABEL_MAP.get(best["label"].lower(), best["label"].upper())

        return SentimentResult(
            text=cleaned,
            label=label,
            score=round(best["score"], 4),
            raw_scores=raw_scores,
        )

    def analyze_batch(self, texts: list[str]) -> list[SentimentResult]:
        """Analyse plusieurs textes d'un coup (plus efficace qu'un par un)."""
        return [self.analyze(t) for t in texts]
