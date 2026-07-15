import time
import sys
import os
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.rule import Rule
from rich.markdown import Markdown
from rich import box
from rich.progress import Progress, SpinnerColumn, TextColumn

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from agent.agent import EmailAgent
from agent.pipeline import EmailPipeline
from gmail.reader import fetch_emails

console = Console()

SCENARIOS = {
    1: "Lecture et classification des emails",
    2: "Détection des emails urgents",
    3: "Génération de réponses automatiques",
    4: "Envoi d'emails en masse personnalisés",
    5: "Mémoire conversationnelle",
}


def pause(seconds: float = 1.5) -> None:
    """Pause entre les étapes pour la lisibilité."""
    time.sleep(seconds)


def print_scenario_header(num: int, title: str) -> None:
    """Affiche l'en-tête d'un scénario."""
    console.print()
    console.print(Rule(
        f"[bold cyan] Scénario {num} : {title} [/bold cyan]",
        style="cyan"
    ))
    console.print()
    pause(0.5)


def print_step(step: str, description: str) -> None:
    """Affiche une étape numérotée."""
    console.print(f"  [bold yellow]→[/bold yellow] [bold]{step}[/bold]"
                  f" [dim]{description}[/dim]")


def run_agent_with_display(agent, instruction: str) -> str:
    """
    Lance l'agent et affiche le raisonnement étape par étape.
    Retourne la réponse finale.
    """
    console.print(
        f"\n  [bold cyan]Instruction :[/bold cyan] "
        f"[italic]{instruction}[/italic]\n"
    )
    pause(0.5)

    final_response = ""
    step_count = 0

    for node_name, message in agent.stream_chat(instruction):
        content    = getattr(message, "content", "")
        tool_calls = getattr(message, "tool_calls", [])

        if node_name == "agent" and tool_calls:
            for tc in tool_calls:
                name = tc.get("name", "?")
                args = tc.get("args", {})
                console.print(
                    f"  [yellow]⚙[/yellow]  Calling [cyan]{name}[/cyan]",
                    end=""
                )
                # Afficher l'arg le plus important
                main_args = {
                    k: str(v)[:50]
                    for k, v in args.items()
                    if k in ("query", "email_id", "to", "topic", "max_results")
                }
                if main_args:
                    args_str = ", ".join(
                        f"{k}={v}" for k, v in main_args.items()
                    )
                    console.print(f"  [dim]({args_str})[/dim]", end="")
                console.print()
                step_count += 1

        elif node_name == "tools" and content:
            preview = content[:100].replace("\n", " ")
            console.print(
                f"  [blue]✓[/blue]  [dim]Result: {preview}...[/dim]"
            )

        elif node_name == "agent" and content and not tool_calls:
            final_response = content

    if final_response:
        console.print()
        console.print(Panel(
            Markdown(final_response),
            title="[bold green]Agent Response[/bold green]",
            border_style="green",
            box=box.ROUNDED,
            padding=(0, 1),
        ))

    console.print(f"  [dim]({step_count} tool calls)[/dim]")
    return final_response


# ----------------------------------------------------------
# SCÉNARIO 1 : Lecture et Classification
# ----------------------------------------------------------
def scenario_1(agent) -> None:
    print_scenario_header(1, SCENARIOS[1])
    console.print(
        "  L'agent lit les 5 derniers emails et les classe automatiquement\n"
        "  par catégorie (RECLAMATION / INFORMATION / SUPPORT / COMMERCIAL)\n"
        "  et par niveau de priorité (URGENT / NORMAL / LOW).\n"
    )
    pause()

    run_agent_with_display(
        agent,
        "Read my 5 most recent emails, classify each one by category "
        "and priority, then show me a clear summary table."
    )
    pause(2)


# ----------------------------------------------------------
# SCÉNARIO 2 : Détection des Urgents
# ----------------------------------------------------------
def scenario_2(agent) -> None:
    print_scenario_header(2, SCENARIOS[2])
    console.print(
        "  L'agent scanne la boîte de réception et identifie\n"
        "  automatiquement les emails qui nécessitent une réponse\n"
        "  immédiate (score d'urgence ≥ 7/10).\n"
    )
    pause()

    run_agent_with_display(
        agent,
        "Check my unread emails and identify any urgent ones "
        "that need immediate attention. For each urgent email, "
        "explain why it is urgent and what action is required."
    )
    pause(2)


# ----------------------------------------------------------
# SCÉNARIO 3 : Génération de Réponses
# ----------------------------------------------------------
def scenario_3(agent) -> None:
    print_scenario_header(3, SCENARIOS[3])
    console.print(
        "  L'agent lit les emails non lus, identifie ceux qui\n"
        "  nécessitent une réponse,\n"
        "  et génère une réponse professionnelle pour chacun.\n"
    )
    pause()

    console.print("\n  [bold cyan]Instruction :[/bold cyan] Process unread emails and suggest replies for SUPPORT/RECLAMATION\n")

    emails = fetch_emails(max_results=20, query="is:unread")
    if not emails:
        console.print("  [yellow]No unread emails found.[/yellow]")
        return

    pipeline = EmailPipeline()
    replied_count = 0

    for email in emails:
        result = pipeline.analyze(email)
        replied_count += 1
        console.print(Panel(
            f"[bold]{email.subject}[/bold]\n"
            f"From: {email.sender}\n"
            f"Category: {result.classification.category}\n"
            f"Priority: {result.priority.priority} ({result.priority.urgency_score}/10)\n\n"
            f"[bold]Suggested reply:[/bold]\n{result.reply.reply}",
            title=f"Reply suggestion #{replied_count}",
            border_style="green",
            box=box.ROUNDED,
        ))

    if replied_count == 0:
        console.print("  [yellow]No emails found in the unread inbox.[/yellow]")
    pause(2)


# ----------------------------------------------------------
# SCÉNARIO 4 : Bulk Email Personnalisé
# ----------------------------------------------------------
def scenario_4(agent) -> None:
    print_scenario_header(4, SCENARIOS[4])
    console.print(
        "  L'agent génère des emails différents et personnalisés\n"
        "  pour plusieurs destinataires en fonction de leur rôle.\n"
        "  [dim](dry_run = pas d'envoi réel pour la démo)[/dim]\n"
    )
    pause()

    run_agent_with_display(
        agent,
        "Generate personalized emails (dry run, do not actually send) "
        "for these 3 people about our weekly team meeting on Monday at 9am:\n"
        "1. Alice (alice@example.com) - Project Manager - "
        "needs to prepare the agenda\n"
        "2. Bob (bob@example.com) - Developer - "
        "needs to demo the new feature\n"
        "3. Carol (carol@example.com) - QA Engineer - "
        "needs to present the test results\n"
        "Make each email unique and relevant to their specific role."
    )
    pause(2)


# ----------------------------------------------------------
# SCÉNARIO 5 : Mémoire Conversationnelle
# ----------------------------------------------------------
def scenario_5(agent) -> None:
    print_scenario_header(5, SCENARIOS[5])
    console.print(
        "  Démonstration de la mémoire : l'agent se souvient\n"
        "  du contexte entre les messages sans que l'utilisateur\n"
        "  ait besoin de répéter les informations.\n"
    )
    pause()

    # Tour 1
    console.print("  [bold]Turn 1[/bold] — Lecture initiale")
    run_agent_with_display(
        agent,
        "Read my 3 most recent emails and tell me "
        "what categories they belong to."
    )
    pause(1.5)

    # Tour 2 — se souvient des emails du tour 1
    console.print("  [bold]Turn 2[/bold] — L'agent se souvient")
    run_agent_with_display(
        agent,
        "Among the emails you just read, "
        "which one has the highest urgency score ?"
    )
    pause(1.5)


def main() -> None:
    console.print("[bold yellow]Loading agent...[/bold yellow]")
    agent = EmailAgent()
    console.print("[green]Agent ready.[/green]")

    scenarios = [scenario_1, scenario_2, scenario_3, scenario_4, scenario_5]
    if len(sys.argv) > 1:
        try:
            selected = int(sys.argv[1])
            if 1 <= selected <= len(scenarios):
                scenarios = [scenarios[selected - 1]]
        except ValueError:
            pass

    for scenario in scenarios:
        scenario(agent)


if __name__ == "__main__":
    main()