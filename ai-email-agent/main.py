from rich.console import Console
from rich.panel import Panel
from rich.markdown import Markdown
from rich.rule import Rule
from rich.table import Table
from rich import box
from agent.agent import EmailAgent

console = Console()

HELP_TEXT = """
[bold cyan]Available commands:[/bold cyan]
  [yellow]quit[/yellow]       → exit
  [yellow]reset[/yellow]      → clear conversation memory
  [yellow]memory[/yellow]     → show memory statistics
  [yellow]demo[/yellow]       → run automated demo
  [yellow]bulk[/yellow]       → run bulk email demo
  [yellow]help[/yellow]       → show this help

[bold cyan]Example instructions:[/bold cyan]
  Read my unread emails and classify them
  Find urgent emails and suggest replies for each
  Send an email to [address] about [topic]
  Send personalized emails to Alice (project manager), Bob (developer),
    and Carol (designer) about the Q3 kickoff meeting on Friday
  What emails did you read earlier?
  Reply to the last complaint you found
"""


def print_step(node_name: str, message) -> None:
    """Affiche une étape du raisonnement de l'agent."""
    content    = getattr(message, "content", "")
    tool_calls = getattr(message, "tool_calls", [])

    if node_name == "agent" and tool_calls:
        for tc in tool_calls:
            name = tc.get("name", "?")
            args = tc.get("args", {})
            console.print(f"  [yellow]→[/yellow] [cyan]{name}[/cyan]", end="")
            # Afficher les args importants
            for k, v in args.items():
                v_str = str(v)[:60].replace("\n", " ")
                console.print(f"  [dim]{k}={v_str}[/dim]", end="")
            console.print()

    elif node_name == "tools" and content:
        # Résumé du résultat de l'outil
        preview = content[:120].replace("\n", " ")
        console.print(f"  [blue]←[/blue] [dim]{preview}...[/dim]")


def show_memory_stats(agent: EmailAgent) -> None:
    """Affiche les statistiques de mémoire."""
    stats = agent.memory.display_stats()
    table = Table(box=box.SIMPLE, show_header=False)
    table.add_column("Key",   style="cyan")
    table.add_column("Value", style="bold")
    table.add_row("Conversation turns",  str(stats["turns"]))
    table.add_row("Messages in memory",  str(stats["total_messages"]))
    table.add_row("Session duration",    f"{stats['duration_min']} min")
    console.print(table)


def run_bulk_demo(agent: EmailAgent) -> None:
    """Démo du bulk email avec personnalisation."""
    console.print(Panel(
        "[bold]Bulk Email Demo[/bold]\n"
        "Sending personalized emails to 3 recipients with different contexts.",
        border_style="cyan"
    ))

    instruction = (
        "Send personalized emails to these 3 people about our Q3 project kickoff meeting "
        "on Wednesday at 10am. Each email should be tailored to their role:\n"
        "1. Alice Dupont (alice@example.com) - Project Manager - "
        "she needs to prepare the agenda and lead the meeting\n"
        "2. Bob Martin (bob@example.com) - Lead Developer - "
        "he needs to present the technical roadmap\n"
        "3. Carol Petit (carol@example.com) - Designer - "
        "she needs to show the new UI mockups\n"
        "Use dry_run=true since these are example addresses."
    )

    console.print(f"[cyan]Instruction:[/cyan] {instruction[:100]}...\n")
    console.print("[yellow]Running agent...[/yellow]\n")

    final_response = ""
    for node_name, message in agent.stream_chat(instruction):
        print_step(node_name, message)
        content    = getattr(message, "content", "")
        tool_calls = getattr(message, "tool_calls", [])
        if content and not tool_calls and node_name == "agent":
            final_response = content

    if final_response:
        console.print(Panel(
            Markdown(final_response),
            title="[green]Agent Response[/green]",
            border_style="green",
        ))


def run_interactive(agent: EmailAgent) -> None:
    """Boucle de conversation interactive."""
    console.print(Panel(HELP_TEXT, title="[bold blue]AI Email Agent[/bold blue]",
                        border_style="blue", box=box.ROUNDED))

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
        elif cmd == "reset":
            agent.reset_memory()
            console.print("[green]Memory cleared. New conversation started.[/green]")
            continue
        elif cmd == "memory":
            show_memory_stats(agent)
            continue
        elif cmd == "help":
            console.print(HELP_TEXT)
            continue
        elif cmd == "bulk":
            run_bulk_demo(agent)
            continue
        elif cmd == "demo":
            user_input = "Read my 3 most recent emails, classify each one, and give me a summary table."

        # Lancer l'agent en streaming
        console.print(f"\n[bold]Agent thinking...[/bold]\n")
        final_response = ""

        try:
            for node_name, message in agent.stream_chat(user_input):
                print_step(node_name, message)
                content    = getattr(message, "content", "")
                tool_calls = getattr(message, "tool_calls", [])
                if content and not tool_calls and node_name == "agent":
                    final_response = content

        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
            import traceback
            traceback.print_exc()
            continue

        # Réponse finale
        if final_response:
            console.print()
            console.print(Panel(
                Markdown(final_response),
                title="[bold green]Agent[/bold green]",
                border_style="green",
                box=box.ROUNDED,
            ))

        # Afficher tour et nb de messages en mémoire
        stats = agent.memory.display_stats()
        console.print(
            f"[dim]Turn {stats['turns']} | "
            f"{stats['total_messages']} messages in memory[/dim]"
        )


if __name__ == "__main__":
    import sys

    console.print("[yellow]Loading agent...[/yellow]")
    agent = EmailAgent()
    console.print("[green]Agent ready.[/green]\n")

    if len(sys.argv) > 1 and sys.argv[1] == "bulk":
        run_bulk_demo(agent)
    else:
        run_interactive(agent)