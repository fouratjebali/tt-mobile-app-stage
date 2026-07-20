"""
Lecture des notifications de réseaux sociaux qui arrivent dans Gmail.

Hypothèse (à valider avec l'admin) : l'admin configure les réseaux sociaux
(Facebook, Instagram, LinkedIn, TikTok, ...) pour qu'ils envoient un e-mail
de notification à chaque nouveau commentaire ou "j'aime" reçu sur une page/publication.

Ce module lit ces e-mails via gmail/reader.py (déjà utilisé par l'Agent 1)
et essaie d'en extraire des informations structurées :
  - la plateforme concernée
  - le type d'évènement (commentaire / like)
  - l'auteur (si détectable)
  - le texte du commentaire (si détectable)
  - le lien vers le post

IMPORTANT : le format réel des e-mails de notification varie selon chaque
réseau social et peut changer avec le temps. Les heuristiques ci-dessous
sont un point de départ raisonnable, mais il faudra très probablement les
ajuster une fois que tu auras de vrais exemples d'e-mails de notification
sous la main (voir la fonction debug_dump_raw_body ci-dessous pour t'aider
à ajuster les règles).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional

from gmail.reader import fetch_emails, Email


@dataclass
class SocialEvent:
    email_id: str
    platform: str          # Facebook | Instagram | LinkedIn | TikTok | Twitter/X | Unknown
    event_type: str         # comment | like | unknown
    author: Optional[str]
    text: Optional[str]     # contenu du commentaire, None pour un like
    post_url: Optional[str]
    date: str
    raw_subject: str


_PLATFORM_HINTS = {
    "facebook": "Facebook",
    "instagram": "Instagram",
    "linkedin": "LinkedIn",
    "tiktok": "TikTok",
    "twitter": "Twitter/X",
    "youtube": "YouTube",
}

_COMMENT_HINTS = (
    "commented", "a commenté", "new comment", "nouveau commentaire",
    "replied", "a répondu",
)

_LIKE_HINTS = (
    "liked", "a aimé", "new like", "reacted", "a réagi", "réaction",
)

_URL_RE = re.compile(r"https?://\S+")
_QUOTED_TEXT_RE = re.compile(r'"([^"]{2,500})"')
_AUTHOR_PREFIX_RE = re.compile(
    r"^([A-Za-zÀ-ÿ' \-]{2,60}?)\s+(commented|a comment[ée]|liked|a aim[ée]|replied|a répondu)",
    re.IGNORECASE,
)

# Lignes/mentions "de service" à retirer du corps avant de le considérer
# comme le texte du commentaire (boilerplate ajouté par les templates
# d'e-mail de notification, ou par des outils comme Zapier).
_BOILERPLATE_PATTERNS = (
    re.compile(r"view comment\s*:?.*", re.IGNORECASE),
    re.compile(r"voir le commentaire\s*:?.*", re.IGNORECASE),
    re.compile(r"commented on your post\s*:?", re.IGNORECASE),
    re.compile(r"a comment[ée] votre publication\s*:?", re.IGNORECASE),
    re.compile(r"liked your (post|page)\s*:?", re.IGNORECASE),
    re.compile(r"a aim[ée] votre (post|page)\s*:?", re.IGNORECASE),
)


def _detect_platform(subject: str, sender: str, body: str) -> str:
    haystack = f"{subject} {sender} {body}".lower()
    for hint, name in _PLATFORM_HINTS.items():
        if hint in haystack:
            return name
    return "Unknown"


def _detect_event_type(subject: str, body: str) -> str:
    haystack = f"{subject} {body}".lower()
    if any(h in haystack for h in _COMMENT_HINTS):
        return "comment"
    if any(h in haystack for h in _LIKE_HINTS):
        return "like"
    return "unknown"


def _extract_author(subject: str) -> Optional[str]:
    match = _AUTHOR_PREFIX_RE.match(subject.strip())
    if match:
        return match.group(1).strip()
    return None


def _clean_body_fallback(body: str, author: Optional[str]) -> Optional[str]:
    """
    Nettoie le corps de l'e-mail pour en faire un texte de commentaire
    exploitable, quand aucun texte entre guillemets n'a été trouvé.

    Retire : les URLs, les mentions "de service" (boilerplate), le nom de
    l'auteur s'il apparaît en début de ligne, et les espaces superflus.
    """
    cleaned = body or ""

    # Retirer les URLs
    cleaned = _URL_RE.sub("", cleaned)

    # Retirer les phrases de service connues (view comment, commented on your post, ...)
    for pattern in _BOILERPLATE_PATTERNS:
        cleaned = pattern.sub("", cleaned)

    # Retirer le nom de l'auteur s'il est répété en début de texte
    if author:
        cleaned = re.sub(rf"^\s*{re.escape(author)}\s*[:,-]?\s*", "", cleaned, flags=re.IGNORECASE)

    # Normaliser les espaces/retours à la ligne multiples
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    return cleaned if cleaned else None


def _extract_comment_text(body: str, author: Optional[str] = None) -> Optional[str]:
    # 1) Essai prioritaire : texte entre guillemets (format explicite "...")
    match = _QUOTED_TEXT_RE.search(body)
    if match:
        return match.group(1).strip()

    # 2) Repli : nettoyer le corps entier et l'utiliser tel quel
    #    (utile quand la source, ex. Zapier, n'ajoute pas de guillemets)
    return _clean_body_fallback(body, author)


def _extract_post_url(body: str) -> Optional[str]:
    match = _URL_RE.search(body)
    return match.group(0) if match else None


def parse_social_email(email: Email) -> SocialEvent:
    """Transforme un e-mail brut de notification en SocialEvent structuré."""
    platform = _detect_platform(email.subject, email.sender, email.body)
    event_type = _detect_event_type(email.subject, email.body)
    author = _extract_author(email.subject)
    text = _extract_comment_text(email.body, author) if event_type == "comment" else None
    post_url = _extract_post_url(email.body)

    return SocialEvent(
        email_id=email.id,
        platform=platform,
        event_type=event_type,
        author=author,
        text=text,
        post_url=post_url,
        date=email.date,
        raw_subject=email.subject,
    )


def fetch_social_events(
    query: str = "(facebook OR instagram OR linkedin OR tiktok) newer_than:7d",
    max_results: int = 20,
) -> List[SocialEvent]:
    """
    Récupère et parse les e-mails de notification de réseaux sociaux.

    Args:
        query: requête de recherche Gmail pour cibler les notifications
               (à adapter selon les expéditeurs réels que l'admin reçoit,
               ex: 'from:notification@facebookmail.com')
        max_results: nombre max d'e-mails à scanner

    Returns:
        Liste de SocialEvent
    """
    emails = fetch_emails(max_results=max_results, query=query)
    return [parse_social_email(e) for e in emails]


def get_social_event_by_id(email_id: str) -> Optional[SocialEvent]:
    """
    Récupère et parse UN SEUL événement social par son email_id exact.

    Existe pour éviter que le LLM ait à recopier lui-même le texte d'un
    commentaire (risque d'erreur avec les emojis/caractères spéciaux) :
    ici on ne lui demande de manipuler que l'email_id (alphanumérique,
    toujours copié fidèlement), et c'est le code Python qui va chercher
    et transmet le vrai texte directement, sans repasser par une
    "récitation" du LLM.
    """
    from gmail.reader import fetch_single_email

    email = fetch_single_email(email_id)
    if not email:
        return None
    return parse_social_email(email)


def debug_dump_raw_body(email_id: str) -> str:
    """
    Utilitaire de debug : affiche le sujet + corps brut d'un e-mail donné,
    pour t'aider à ajuster les règles d'extraction (_COMMENT_HINTS, regex, etc.)
    une fois que tu as de vrais exemples de notifications.
    """
    from gmail.reader import fetch_single_email

    email = fetch_single_email(email_id)
    if not email:
        return f"Email {email_id} introuvable."
    return f"SUBJECT: {email.subject}\nSENDER: {email.sender}\n\nBODY:\n{email.body}"
