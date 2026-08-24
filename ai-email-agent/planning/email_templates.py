from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from html import escape
from typing import Any


@dataclass(slots=True)
class RenderedTemplate:
    subject: str
    body: str
    html_body: str


class TrainingEmailTemplates:
    """Formal French templates for Tunisie Telecom training communications."""

    def render(
        self,
        session: dict[str, Any],
        *,
        email_type: str,
        include_population: bool = True,
    ) -> RenderedTemplate:
        if email_type == "confirmation_presence":
            return self.confirmation_presence(session, include_population=include_population)
        if email_type == "sensibilisation":
            return self.sensibilisation(session, include_population=include_population)
        if email_type == "rappel":
            return self.rappel(session, include_population=include_population)
        if email_type == "report":
            return self.report(session, include_population=include_population)
        if email_type == "annulation":
            return self.annulation(session, include_population=include_population)
        raise ValueError(f"Unsupported training email type: {email_type}")

    def confirmation_presence(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> RenderedTemplate:
        subject = f"Confirmation de présence formation {module(session)}"
        intro = (
            "Dans le cadre de la mise en œuvre du plan de formation 2026 et afin de "
            "concrétiser les besoins exprimés par les collaborateurs lors de la campagne "
            "de recueil des besoins en formation, nous vous invitons à confirmer votre "
            "présence dans les meilleurs délais."
        )
        closing = (
            "Nous attirons également votre attention sur le fait que les absences, en "
            "particulier lorsqu'elles ne sont pas signalées à temps, peuvent impacter "
            "le bon déroulement de la session.<br><br>"
            "Prière de nous confirmer votre présence ou de nous signaler tout empêchement "
            "dans les meilleurs délais."
        )
        return self._render_standard(
            session,
            subject=subject,
            intro=intro,
            closing=closing,
            include_population=include_population,
            table_title="Participants concernés",
        )

    def sensibilisation(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> RenderedTemplate:
        subject = f"Sensibilisation à participer à la formation {module(session)}"
        intro = (
            "Dans le cadre du développement des compétences de nos collaborateurs, nous "
            f"organisons une formation sur « {module(session)} »."
        )
        closing = (
            "Cette session offrira l'opportunité d'acquérir de nouvelles connaissances "
            "et de renforcer les compétences utiles au quotidien professionnel.<br><br>"
            "Nous invitons les responsables RH à relayer cette information et à encourager "
            "la participation des collaborateurs concernés.<br><br>"
            "Votre mobilisation contribuera au succès de cette action de formation.<br><br>"
            "Pour toute information complémentaire, n'hésitez pas à nous contacter."
        )
        return self._render_standard(
            session,
            subject=subject,
            intro=intro,
            closing=closing,
            include_population=include_population,
            table_title="Population cible",
        )

    def rappel(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> RenderedTemplate:
        subject = f"Rappel formation {module(session)}"
        intro = f"Nous vous rappelons que la formation « {module(session)} » est programmée prochainement."
        closing = (
            "Merci de prendre les dispositions nécessaires pour assurer votre présence "
            "et de nous informer rapidement en cas d'empêchement."
        )
        return self._render_standard(
            session,
            subject=subject,
            intro=intro,
            closing=closing,
            include_population=include_population,
            table_title="Participants concernés",
        )

    def report(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> RenderedTemplate:
        subject = f"Report de la formation {module(session)}"
        intro = f"Nous vous informons que la formation « {module(session)} » est reportée."
        closing = "Une nouvelle communication vous sera transmise dès confirmation de la date retenue."
        return self._render_standard(
            session,
            subject=subject,
            intro=intro,
            closing=closing,
            include_population=include_population,
            table_title="Participants concernés",
        )

    def annulation(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> RenderedTemplate:
        subject = f"Annulation de la formation {module(session)}"
        intro = f"Nous vous informons que la formation « {module(session)} » est annulée."
        closing = (
            "Nous vous remercions pour votre compréhension et vous tiendrons informés "
            "en cas de reprogrammation."
        )
        return self._render_standard(
            session,
            subject=subject,
            intro=intro,
            closing=closing,
            include_population=include_population,
            table_title="Participants concernés",
        )

    def _render_standard(
        self,
        session: dict[str, Any],
        *,
        subject: str,
        intro: str,
        closing: str,
        include_population: bool,
        table_title: str,
    ) -> RenderedTemplate:
        details_text = details_block_text(session)
        participants_text = participants_table_text(session, title=table_title) if include_population else ""
        body_parts = [
            "Bonjour,",
            "",
            intro,
            "",
            details_text,
        ]
        if participants_text:
            body_parts.extend(["", participants_text])
        body_parts.extend(["", html_to_text(closing), "", "Cordialement,"])
        body = "\n".join(body_parts)

        html_parts = [
            "<p>Bonjour,</p>",
            f"<p>{escape(intro)}</p>",
            details_block_html(session),
        ]
        if include_population:
            participants_html = participants_table_html(session, title=table_title)
            if participants_html:
                html_parts.append(participants_html)
        html_parts.extend([f"<p>{closing}</p>", "<p>Cordialement,</p>"])
        return RenderedTemplate(
            subject=subject,
            body=body,
            html_body=wrap_html("\n".join(html_parts)),
        )


def details_block_text(session: dict[str, Any]) -> str:
    return "\n".join(
        [
            f"Thème de la formation : {module(session)}",
            f"Durée du cours : {date_range(session)}",
            f"Lieu principal : {value(session, 'location', 'À préciser')}",
            f"Cabinet de Formation : {training_provider(session)}",
        ]
    )


def details_block_html(session: dict[str, Any]) -> str:
    details = [
        ("Thème de la formation", module(session)),
        ("Durée du cours", date_range(session)),
        ("Lieu principal", value(session, "location", "À préciser")),
        ("Cabinet de Formation", training_provider(session)),
    ]
    lines = []
    for label, detail in details:
        lines.append(
            "<p style=\"margin: 0 0 12px;\">"
            f"<strong>{escape(label)} :</strong> "
            f"<span style=\"color: #19a8d8; font-weight: 700;\">{escape(detail)}</span>"
            "</p>"
        )
    return "\n".join(lines)


def participants_table_text(session: dict[str, Any], *, title: str) -> str:
    rows = participant_rows(session)
    if not rows:
        return ""
    lines = [f"{title} :", "Matricule | Nom et prénom"]
    lines.extend(f"{matricule} | {name}" for matricule, name in rows)
    return "\n".join(lines)


def participants_table_html(session: dict[str, Any], *, title: str) -> str:
    rows = participant_rows(session)
    if not rows:
        return ""
    body_rows = "\n".join(
        "<tr>"
        f"<td style=\"border: 1px solid #6f6a64; padding: 4px 8px;\">{escape(matricule)}</td>"
        f"<td style=\"border: 1px solid #6f6a64; padding: 4px 8px;\">{escape(name)}</td>"
        "</tr>"
        for matricule, name in rows
    )
    return (
        f"<p style=\"margin: 14px 0 6px;\"><strong>{escape(title)} :</strong></p>"
        "<table cellspacing=\"0\" cellpadding=\"0\" "
        "style=\"border-collapse: collapse; font-family: Arial, sans-serif; font-size: 14px; min-width: 420px;\">"
        "<thead><tr>"
        "<th style=\"border: 1px solid #6f6a64; padding: 4px 8px; text-align: left;\">Matricule</th>"
        "<th style=\"border: 1px solid #6f6a64; padding: 4px 8px; text-align: left;\">Nom et prénom</th>"
        "</tr></thead>"
        f"<tbody>{body_rows}</tbody>"
        "</table>"
    )


def participant_rows(session: dict[str, Any]) -> list[tuple[str, str]]:
    rows = []
    for participant in session.get("participants", []) or []:
        matricule = str(participant.get("matricule") or "").strip()
        name = str(participant.get("full_name") or "").strip()
        if matricule or name:
            rows.append((matricule, name))
    return rows


def module(session: dict[str, Any]) -> str:
    return value(session, "module", "la formation")


def training_provider(session: dict[str, Any]) -> str:
    selected_trainer = value(session, "selected_trainer", "")
    trainer = value(session, "trainer", "")
    cabinet = value(session, "cabinet", "")
    if selected_trainer:
        return selected_trainer
    if cabinet.lower().strip() == "formateur interne" and trainer:
        return trainer
    if cabinet:
        return cabinet
    return trainer or "À préciser"


def date_range(session: dict[str, Any]) -> str:
    start = value(session, "start_date", "")
    end = value(session, "end_date", "")
    if start and end and start != end:
        return f"du {format_date(start)} au {format_date(end)}"
    if start:
        return f"le {format_date(start)}"
    return "À préciser"


def format_date(raw_value: str) -> str:
    try:
        return datetime.fromisoformat(raw_value).strftime("%d/%m/%Y")
    except ValueError:
        return raw_value


def value(session: dict[str, Any], key: str, fallback: str) -> str:
    raw_value = str(session.get(key) or "").strip()
    return raw_value if raw_value else fallback


def html_to_text(content: str) -> str:
    return content.replace("<br><br>", "\n\n").replace("<br>", "\n")


def wrap_html(content: str) -> str:
    return (
        "<!doctype html>"
        "<html><body style=\"font-family: Arial, sans-serif; font-size: 14px; color: #1f1f1f; line-height: 1.35;\">"
        f"{content}"
        "</body></html>"
    )
