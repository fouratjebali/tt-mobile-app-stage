"""
Point d'entrée en ligne de commande pour l'Agent 2 (réseaux sociaux).

Usage:
    python main_agent2.py
"""

from rich.console import Console
from rich.panel import Panel
from rich.markdown import Markdown
from rich.rule import Rule
from rich import box

from agent2.agent import JuryAndSocialAgent

console = Console()

HELP_TEXT = """
[bold cyan]Agent 2 — Social Media [/bold cyan]

  [yellow]quit[/yellow]   → exit
  [yellow]reset[/yellow]  → clear conversation memory (nouvelle conversation)
  [yellow]help[/yellow]   → show this help

[bold cyan]Example instructions:[/bold cyan]
  Read the latest social media notifications and analyze the sentiment of each comment
  Analyze the sentiment of this comment: "Votre service est vraiment nul, je suis déçu"
  Review this reply against the original email and tell me if it's safe to send:
    Original: [paste original email]
    Reply: [paste Agent 1's reply]
  Send this to the admin for approval with verdict APPROVED
"""


def print_step(node_name: str, message) -> None:
    """Affiche une étape du raisonnement de l'agent (même logique que main.py)."""
    content = getattr(message, "content", "")
    tool_calls = getattr(message, "tool_calls", [])

    if node_name == "agent" and tool_calls:
        for tc in tool_calls:
            name = tc.get("name", "?")
            args = tc.get("args", {})
            console.print(f"  [yellow]→[/yellow] [cyan]{name}[/cyan]", end="")
            for k, v in args.items():
                v_str = str(v)[:60].replace("\n", " ")
                console.print(f"  [dim]{k}={v_str}[/dim]", end="")
            console.print()

    elif node_name == "tools" and content:
        preview = content[:120].replace("\n", " ")
        console.print(f"  [blue]←[/blue] [dim]{preview}...[/dim]")


def run_interactive(agent: JuryAndSocialAgent) -> None:
    console.print(Panel(
        HELP_TEXT,
        title="[bold blue]Agent Social Media[/bold blue]",
        border_style="blue",
        box=box.ROUNDED,
    ))

    while True:
        console.print(Rule(style="dim"))
        try:
            user_input = console.input("[bold cyan]You:[/bold cyan] ").strip()
        except (KeyboardInterrupt, EOFError):
            console.print("\n[yellow]Goodbye![/yellow]")
            break

        if not user_input:
            continue

        cmd = user_input.lower()
        if cmd == "quit":
            console.print("[yellow]Goodbye![/yellow]")
            break
        if cmd == "reset":
            agent.reset_memory()
            console.print("[green]Memory cleared. New conversation started.[/green]")
            continue
        if cmd == "help":
            console.print(HELP_TEXT)
            continue

        console.print("\n[bold]Agent 2 thinking...[/bold]\n")
        final_response = ""

        try:
            for node_name, message in agent.stream(user_input):
                print_step(node_name, message)
                content = getattr(message, "content", "")
                tool_calls = getattr(message, "tool_calls", [])
                if content and not tool_calls and node_name == "agent":
                    final_response = content
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            import traceback
            traceback.print_exc()
            continue

        if final_response:
            console.print()
            console.print(Panel(
                Markdown(final_response),
                title="[bold green]Agent 2[/bold green]",
                border_style="green",
                box=box.ROUNDED,
            ))


if __name__ == "__main__":
    console.print("[yellow]Loading Agent 2 (Jury Social Media)...[/yellow]")
    console.print("[dim]Chargement du modèle de sentiment (peut prendre un moment "
                   "au tout premier lancement, le temps de télécharger le modèle)...[/dim]")
    agent = JuryAndSocialAgent()
    console.print("[green]Agent 2 ready.[/green]\n")
    run_interactive(agent)
