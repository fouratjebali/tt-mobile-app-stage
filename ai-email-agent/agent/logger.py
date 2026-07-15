import json
import os
from datetime import datetime
from dataclasses import dataclass, asdict
from statistics import median
from typing import Optional


LOGS_DIR = "data/logs"
DATASET_DIR = "data/training"


@dataclass
class AnalysisLog:
    """Un enregistrement d'analyse pour le dataset."""
    timestamp:          str
    email_subject:      str
    email_sender:       str
    email_body_preview: str
    predicted_category: str
    predicted_priority: str
    confidence:         float
    urgency_score:      int
    summary:            str
    suggested_reply:    str
    # Vérité terrain (à remplir manuellement pour l'évaluation)
    true_category:      Optional[str] = None
    true_priority:      Optional[str] = None
    correct_category:   Optional[bool] = None
    correct_priority:   Optional[bool] = None
    notes:              str = ""


class AgentLogger:
    """
    Enregistre les analyses de l'agent dans des fichiers JSON.
    Utilisé pour construire le dataset d'évaluation et
    mesurer les performances.
    """

    def __init__(self):
        os.makedirs(LOGS_DIR,    exist_ok=True)
        os.makedirs(DATASET_DIR, exist_ok=True)
        self.session_file = os.path.join(
            LOGS_DIR,
            f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        self.session_logs: list[AnalysisLog] = []

    def log_analysis(
        self,
        email_subject:      str,
        email_sender:       str,
        email_body:         str,
        predicted_category: str,
        predicted_priority: str,
        confidence:         float,
        urgency_score:      int,
        summary:            str,
        suggested_reply:    str,
    ) -> AnalysisLog:
        """
        Enregistre une analyse dans le fichier de session.

        Returns:
            L'objet AnalysisLog créé
        """
        log = AnalysisLog(
            timestamp=datetime.now().isoformat(),
            email_subject=email_subject,
            email_sender=email_sender,
            email_body_preview=email_body[:300],
            predicted_category=predicted_category,
            predicted_priority=predicted_priority,
            confidence=confidence,
            urgency_score=urgency_score,
            summary=summary,
            suggested_reply=suggested_reply,
        )

        self.session_logs.append(log)
        self._save_session()
        return log

    def _save_session(self) -> None:
        """Sauvegarde la session courante dans le fichier JSON."""
        data = [asdict(log) for log in self.session_logs]
        with open(self.session_file, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def export_for_evaluation(self, output_file: str = None) -> str:
        """
        Exporte les logs de la session dans un fichier
        prêt pour l'évaluation manuelle.
        Les champs true_category et true_priority sont vides
        et doivent être remplis manuellement.

        Returns:
            Chemin du fichier exporté
        """
        if not output_file:
            output_file = os.path.join(
                DATASET_DIR,
                f"eval_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            )

        data = [asdict(log) for log in self.session_logs]
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"Exported {len(data)} records to {output_file}")
        return output_file

    def get_session_stats(self) -> dict:
        """Retourne les statistiques de la session courante."""
        if not self.session_logs:
            return {"total": 0}

        from collections import Counter
        cats   = Counter(l.predicted_category for l in self.session_logs)
        prios  = Counter(l.predicted_priority  for l in self.session_logs)
        avg_conf = median(l.confidence for l in self.session_logs)

        return {
            "total":           len(self.session_logs),
            "categories":      dict(cats),
            "priorities":      dict(prios),
            "avg_confidence":  round(avg_conf, 3),
            "session_file":    self.session_file,
        }


# Instance globale
agent_logger = AgentLogger()