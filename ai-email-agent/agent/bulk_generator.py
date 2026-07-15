import json
from dataclasses import dataclass
from langchain_ollama import OllamaLLM
from langchain_core.prompts import PromptTemplate
from agent.prompts import BULK_PERSONALIZED_PROMPT
from agent.parser import parser
from gmail.sender import send_email, send_bulk_emails
from config.settings import settings


# Dataclasses
@dataclass
class Recipient:
    """Un destinataire avec son contexte personnalisé."""
    name:    str
    email:   str
    role:    str
    context: str   


@dataclass
class GeneratedEmail:
    """Un email généré pour un destinataire."""
    recipient:            Recipient
    subject:              str
    body:                 str
    personalization_note: str
    status:               str = "pending"   # pending | sent | error
    error:                str = ""
    message_id:           str = ""


# ----------------------------------------------------------
# BulkEmailGenerator
# ----------------------------------------------------------

class BulkEmailGenerator:
    """
    Génère et envoie des emails personnalisés à plusieurs destinataires.

    Usage:
        generator = BulkEmailGenerator()
        recipients = [
            Recipient("Alice", "alice@co.com", "Chef de projet",
                      "Elle gère le projet X et a demandé un point hebdo"),
            Recipient("Bob", "bob@co.com", "Développeur",
                      "Il travaille sur le backend, en retard sur la deadline"),
        ]
        results = generator.generate_and_send(
            recipients=recipients,
            topic="Réunion de suivi Q3 — mercredi 10h",
            instructions="Mentionner l'importance de la présence",
            send=True,   # False = dry run, génère sans envoyer
        )
    """

    def __init__(self):
        self.llm = OllamaLLM(
            base_url=settings.OLLAMA_BASE_URL,
            model=settings.OLLAMA_MODEL,
            temperature=0.4,   # un peu plus créatif pour la personnalisation
        )
        self._chain = PromptTemplate.from_template(BULK_PERSONALIZED_PROMPT) | self.llm

    def generate_one(
        self,
        recipient: Recipient,
        topic: str,
        instructions: str = "",
    ) -> GeneratedEmail:
        """
        Génère un email personnalisé pour UN destinataire.

        Args:
            recipient    : le destinataire avec son contexte
            topic        : sujet général de l'email
            instructions : instructions supplémentaires

        Returns:
            GeneratedEmail avec subject et body générés
        """
        raw = self._chain.invoke({
            "name":         recipient.name,
            "email":        recipient.email,
            "role":         recipient.role,
            "context":      recipient.context,
            "topic":        topic,
            "instructions": instructions or "None",
        })

        data = parser.safe_parse(raw, default={
            "subject": f"Message pour {recipient.name}",
            "body":    f"Bonjour {recipient.name},\n\n{topic}\n\nCordialement.",
            "personalization_note": "default fallback used",
        })

        return GeneratedEmail(
            recipient=recipient,
            subject=data.get("subject", ""),
            body=data.get("body", ""),
            personalization_note=data.get("personalization_note", ""),
        )

    def generate_all(
        self,
        recipients: list[Recipient],
        topic: str,
        instructions: str = "",
    ) -> list[GeneratedEmail]:
        """
        Génère des emails personnalisés pour TOUS les destinataires.
        Affiche la progression.

        Args:
            recipients   : liste de destinataires
            topic        : sujet général
            instructions : instructions supplémentaires

        Returns:
            Liste de GeneratedEmail (un par destinataire)
        """
        results = []
        total = len(recipients)

        print(f"\n  Generating {total} personalized emails...")

        for i, recipient in enumerate(recipients, 1):
            print(f"  ({i}/{total}) Generating for {recipient.name} ({recipient.role})...")
            email = self.generate_one(recipient, topic, instructions)
            results.append(email)

        return results

    def send_all(self, generated_emails: list[GeneratedEmail]) -> list[GeneratedEmail]:
        """
        Envoie tous les emails générés via Gmail API.

        Args:
            generated_emails : liste de GeneratedEmail à envoyer

        Returns:
            Même liste avec status mis à jour (sent/error)
        """
        print(f"\n  Sending {len(generated_emails)} emails...")

        for ge in generated_emails:
            try:
                result = send_email(
                    to=ge.recipient.email,
                    subject=ge.subject,
                    body=ge.body,
                )
                ge.status     = "sent"
                ge.message_id = result.get("id", "")
                print(f"  ✓ Sent to {ge.recipient.email}")

            except Exception as e:
                ge.status = "error"
                ge.error  = str(e)
                print(f"  ✗ Error for {ge.recipient.email}: {e}")

        return generated_emails

    def generate_and_send(
        self,
        recipients: list[Recipient],
        topic: str,
        instructions: str = "",
        send: bool = True,
    ) -> list[GeneratedEmail]:
        """
        Pipeline complet : génère puis envoie (ou dry-run).

        Args:
            recipients   : liste de Recipient
            topic        : sujet général
            instructions : instructions optionnelles
            send         : True = envoie vraiment, False = dry run

        Returns:
            Liste de GeneratedEmail avec résultats
        """
        # 1. Générer tous les emails
        generated = self.generate_all(recipients, topic, instructions)

        # 2. Envoyer (ou non)
        if send:
            generated = self.send_all(generated)
        else:
            for ge in generated:
                ge.status = "dry_run"
            print("\n  DRY RUN — emails generated but NOT sent.")

        return generated

    def results_to_json(self, results: list[GeneratedEmail]) -> str:
        """Convertit les résultats en JSON pour l'agent."""
        data = []
        for ge in results:
            data.append({
                "recipient":            ge.recipient.name,
                "email":                ge.recipient.email,
                "subject":              ge.subject,
                "body_preview":         ge.body[:200],
                "personalization_note": ge.personalization_note,
                "status":               ge.status,
                "message_id":           ge.message_id,
                "error":                ge.error,
            })
        sent   = sum(1 for ge in results if ge.status == "sent")
        errors = sum(1 for ge in results if ge.status == "error")
        return json.dumps({
            "total":   len(results),
            "sent":    sent,
            "errors":  errors,
            "dry_run": any(ge.status == "dry_run" for ge in results),
            "results": data,
        }, ensure_ascii=False)