import json
import os
import sys

# Ajouter la racine du projet au path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich import box
except ModuleNotFoundError:
    class _PlainBox:
        ROUNDED = None
        SIMPLE = None

    class _PlainConsole:
        def print(self, *args, **kwargs):
            text = " ".join(str(arg) for arg in args)
            print(text)

    class _PlainPanel:
        def __init__(self, renderable, *args, **kwargs):
            self.renderable = renderable

        def __str__(self):
            return str(self.renderable)

    class _PlainTable:
        def __init__(self, *args, **kwargs):
            self.title = kwargs.get("title", "")
            self.rows = []

        def add_column(self, *args, **kwargs):
            return None

        def add_row(self, *values):
            self.rows.append(values)

        def __str__(self):
            lines = []
            if self.title:
                lines.append(self.title)
            for row in self.rows:
                lines.append(" | ".join(str(value) for value in row))
            return "\n".join(lines)

    Console = _PlainConsole
    Panel = _PlainPanel
    Table = _PlainTable
    box = _PlainBox()
from gmail.reader import fetch_emails
from agent.chains import EmailChains
from agent.logger import AgentLogger

console = Console()


# ----------------------------------------------------------
# Étape A : Collecter et analyser les emails
# ----------------------------------------------------------

def collect_and_analyze(n_emails: int = 20) -> str:
    """
    Récupère N emails, les analyse avec l'agent,
    et sauvegarde les résultats dans un fichier JSON.

    Returns:
        Chemin du fichier JSON créé
    """
    console.print(Panel(
        f"[bold]Step 1 : Collecting and analyzing {n_emails} emails...[/bold]",
        border_style="blue"
    ))

    emails = fetch_emails(max_results=n_emails, query="")
    if not emails:
        console.print("[red]No emails found.[/red]")
        return ""

    console.print(f"[green]{len(emails)} emails retrieved[/green]")

    chains = EmailChains()
    logger = AgentLogger()

    for i, email in enumerate(emails, 1):
        console.print(
            f"  Analyzing ({i}/{len(emails)}) : "
            f"[cyan]{email.subject[:50]}[/cyan]"
        )

        # Classification
        clf = chains.classify(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
        )

        # Priorité
        pri = chains.prioritize(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
            category=clf.category,
        )

        # Résumé
        summ = chains.summarize(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
        )

        # Suggestion
        reply = chains.suggest_reply(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
            category=clf.category,
            priority=pri.priority,
            summary=summ.summary,
        )

        # Logger
        logger.log_analysis(
            email_subject=email.subject,
            email_sender=email.sender,
            email_body=email.body,
            predicted_category=clf.category,
            predicted_priority=pri.priority,
            confidence=clf.confidence,
            urgency_score=pri.urgency_score,
            summary=summ.summary,
            suggested_reply=reply.reply,
        )

    # Exporter pour évaluation manuelle
    output_file = logger.export_for_evaluation()

    console.print(f"\n[green]File saved : {output_file}[/green]")
    console.print(
        "\n[yellow]Next step : open the JSON file and fill in "
        "'true_category' and 'true_priority' for each email.[/yellow]"
    )
    console.print(
        "[yellow]Then run : python data/evaluate.py --compute[/yellow]\n"
    )

    # Afficher un aperçu
    _show_preview_table(logger.session_logs)

    return output_file


def _show_preview_table(logs) -> None:
    """Affiche un tableau des prédictions."""
    table = Table(
        title="Agent Predictions Preview",
        box=box.ROUNDED, show_lines=True
    )
    table.add_column("#",         width=3,  style="dim")
    table.add_column("Subject",   width=30)
    table.add_column("Category",  width=14)
    table.add_column("Conf.",     width=6)
    table.add_column("Priority",  width=9)
    table.add_column("Score",     width=6)

    PRIO_COLORS = {"URGENT": "red", "NORMAL": "yellow", "LOW": "green"}
    CAT_COLORS  = {
        "RECLAMATION": "red", "SUPPORT": "orange3",
        "COMMERCIAL": "blue", "INFORMATION": "cyan"
    }

    for i, log in enumerate(logs, 1):
        cc = CAT_COLORS.get(log.predicted_category, "white")
        pc = PRIO_COLORS.get(log.predicted_priority, "white")
        table.add_row(
            str(i),
            log.email_subject[:28],
            f"[{cc}]{log.predicted_category}[/{cc}]",
            f"{log.confidence:.0%}",
            f"[{pc}]{log.predicted_priority}[/{pc}]",
            f"{log.urgency_score}/10",
        )

    console.print(table)


# ----------------------------------------------------------
# Étape B : Calculer les métriques après annotation manuelle
# ----------------------------------------------------------

def compute_metrics(eval_file: str) -> None:
    """
    Calcule les métriques de performance à partir
    du fichier JSON annoté manuellement.

    Args:
        eval_file : chemin du fichier JSON avec true_category rempli
    """
    console.print(Panel(
        "[bold]Step 2 : Computing evaluation metrics...[/bold]",
        border_style="green"
    ))

    with open(eval_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Filtrer les entrées annotées
    annotated = [
        d for d in data
        if d.get("true_category") and d.get("true_priority")
    ]

    if not annotated:
        console.print(
            "[red]No annotated records found.[/red]\n"
            "[yellow]Open the JSON file and fill in "
            "'true_category' and 'true_priority' for each record.[/yellow]"
        )
        return

    console.print(f"[green]{len(annotated)} annotated records found[/green]\n")

    # ── Métriques catégorie ───────────────────────────────
    cat_correct = sum(
        1 for d in annotated
        if d["predicted_category"] == d["true_category"]
    )
    cat_accuracy = cat_correct / len(annotated)

    # ── Métriques priorité ────────────────────────────────
    pri_correct = sum(
        1 for d in annotated
        if d["predicted_priority"] == d["true_priority"]
    )
    pri_accuracy = pri_correct / len(annotated)

    # ── Métriques par classe (catégorie) ──────────────────
    categories = ["RECLAMATION", "INFORMATION", "SUPPORT", "COMMERCIAL"]
    cat_metrics = {}
    for cat in categories:
        tp = sum(1 for d in annotated
                 if d["predicted_category"] == cat
                 and d["true_category"] == cat)
        fp = sum(1 for d in annotated
                 if d["predicted_category"] == cat
                 and d["true_category"] != cat)
        fn = sum(1 for d in annotated
                 if d["predicted_category"] != cat
                 and d["true_category"] == cat)

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall    = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1        = (2 * precision * recall / (precision + recall)
                     if (precision + recall) > 0 else 0)

        cat_metrics[cat] = {
            "precision": precision,
            "recall":    recall,
            "f1":        f1,
            "tp": tp, "fp": fp, "fn": fn,
        }

    # ── Affichage ─────────────────────────────────────────
    summary_table = Table(title="Overall Accuracy", box=box.SIMPLE)
    summary_table.add_column("Metric",   style="cyan")
    summary_table.add_column("Value",    style="bold")
    summary_table.add_column("Target",   style="dim")
    summary_table.add_column("Status",   style="bold")

    cat_status = "[green]✓ PASS[/green]" if cat_accuracy >= 0.85 else "[red]✗ FAIL[/red]"
    pri_status = "[green]✓ PASS[/green]" if pri_accuracy >= 0.80 else "[red]✗ FAIL[/red]"

    summary_table.add_row(
        "Category Accuracy",
        f"{cat_accuracy:.1%} ({cat_correct}/{len(annotated)})",
        "≥ 85%", cat_status
    )
    summary_table.add_row(
        "Priority Accuracy",
        f"{pri_accuracy:.1%} ({pri_correct}/{len(annotated)})",
        "≥ 80%", pri_status
    )
    console.print(summary_table)

    detail_table = Table(
        title="Per-Category Metrics",
        box=box.ROUNDED, show_lines=True
    )
    detail_table.add_column("Category",  style="cyan", width=14)
    detail_table.add_column("Precision", width=10)
    detail_table.add_column("Recall",    width=10)
    detail_table.add_column("F1 Score",  width=10)
    detail_table.add_column("TP",        width=5, style="green")
    detail_table.add_column("FP",        width=5, style="red")
    detail_table.add_column("FN",        width=5, style="yellow")

    for cat, m in cat_metrics.items():
        f1_color = "green" if m["f1"] >= 0.80 else "red"
        detail_table.add_row(
            cat,
            f"{m['precision']:.1%}",
            f"{m['recall']:.1%}",
            f"[{f1_color}]{m['f1']:.1%}[/{f1_color}]",
            str(m["tp"]), str(m["fp"]), str(m["fn"]),
        )
    console.print(detail_table)

    # ── Afficher les erreurs ──────────────────────────────
    errors = [
        d for d in annotated
        if d["predicted_category"] != d["true_category"]
        or d["predicted_priority"] != d["true_priority"]
    ]

    if errors:
        console.print(f"\n[bold red]{len(errors)} misclassifications :[/bold red]")
        error_table = Table(box=box.SIMPLE, show_lines=True)
        error_table.add_column("Subject",        width=30)
        error_table.add_column("Predicted Cat",  width=14, style="red")
        error_table.add_column("True Cat",       width=14, style="green")
        error_table.add_column("Predicted Prio", width=10, style="red")
        error_table.add_column("True Prio",      width=10, style="green")

        for e in errors:
            error_table.add_row(
                e["email_subject"][:28],
                e["predicted_category"],
                e["true_category"],
                e["predicted_priority"],
                e["true_priority"],
            )
        console.print(error_table)
        console.print(
            "\n[yellow]Use these errors to improve your prompts "
            "in agent/prompts.py[/yellow]"
        )

    # ── Recommandations ───────────────────────────────────
    console.print("\n[bold cyan]Recommendations :[/bold cyan]")
    if cat_accuracy < 0.85:
        console.print(
            "  [red]→ Category accuracy below target.[/red]\n"
            "    Add more examples to CLASSIFICATION_PROMPT.\n"
            "    Check which category is most confused.\n"
        )
    if pri_accuracy < 0.80:
        console.print(
            "  [red]→ Priority accuracy below target.[/red]\n"
            "    Add urgency keywords to PRIORITY_PROMPT.\n"
            "    Check if URGENT emails are being missed.\n"
        )
    if cat_accuracy >= 0.85 and pri_accuracy >= 0.80:
        console.print(
            "  [green]→ Both metrics pass targets. "
            "Agent is performing well ![/green]"
        )


# ----------------------------------------------------------
# Étape C : Annoter le fichier JSON depuis le terminal
# ----------------------------------------------------------

def annotate_interactive(eval_file: str) -> None:
    """
    Interface interactive pour annoter les enregistrements
    directement dans le terminal, sans ouvrir le fichier JSON.
    """
    with open(eval_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    unannotated = [d for d in data if not d.get("true_category")]
    console.print(f"\n[yellow]{len(unannotated)} records to annotate[/yellow]")
    console.print("[dim]Press Ctrl+C to stop and save progress[/dim]\n")

    CATEGORIES = ["RECLAMATION", "INFORMATION", "SUPPORT", "COMMERCIAL"]
    PRIORITIES  = ["URGENT", "NORMAL", "LOW"]

    try:
        for record in unannotated:
            console.print(Panel(
                f"[bold]Subject :[/bold] {record['email_subject']}\n"
                f"[bold]From    :[/bold] {record['email_sender']}\n"
                f"[bold]Preview :[/bold] {record['email_body_preview'][:200]}\n\n"
                f"[bold]Predicted:[/bold] "
                f"{record['predicted_category']} / {record['predicted_priority']}",
                title="Annotate this email",
                border_style="cyan",
            ))

            # Catégorie
            console.print("Categories : " + " | ".join(
                f"[cyan]{i+1}[/cyan]={c}" for i, c in enumerate(CATEGORIES)
            ))
            cat_idx = console.input(
                "True category (1-4, Enter=keep predicted): "
            ).strip()

            if cat_idx == "":
                true_cat = record["predicted_category"]
            elif cat_idx.isdigit() and 1 <= int(cat_idx) <= 4:
                true_cat = CATEGORIES[int(cat_idx) - 1]
            else:
                true_cat = record["predicted_category"]

            # Priorité
            console.print("Priorities : " + " | ".join(
                f"[yellow]{i+1}[/yellow]={p}" for i, p in enumerate(PRIORITIES)
            ))
            pri_idx = console.input(
                "True priority (1-3, Enter=keep predicted): "
            ).strip()

            if pri_idx == "":
                true_pri = record["predicted_priority"]
            elif pri_idx.isdigit() and 1 <= int(pri_idx) <= 3:
                true_pri = PRIORITIES[int(pri_idx) - 1]
            else:
                true_pri = record["predicted_priority"]

            # Mettre à jour
            record["true_category"]    = true_cat
            record["true_priority"]    = true_pri
            record["correct_category"] = (true_cat == record["predicted_category"])
            record["correct_priority"] = (true_pri == record["predicted_priority"])

            status = "[green]✓[/green]" if record["correct_category"] else "[red]✗[/red]"
            console.print(f"{status} Saved\n")

    except KeyboardInterrupt:
        console.print("\n[yellow]Annotation stopped. Saving progress...[/yellow]")

    # Sauvegarder
    with open(eval_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    console.print(f"[green]Saved to {eval_file}[/green]")


# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Agent evaluation tool")
    parser.add_argument("--collect",  type=int, metavar="N",
                        help="Collect and analyze N emails")
    parser.add_argument("--annotate", type=str, metavar="FILE",
                        help="Annotate a JSON eval file interactively")
    parser.add_argument("--compute",  type=str, metavar="FILE",
                        help="Compute metrics from annotated JSON file")
    args = parser.parse_args()

    if args.collect:
        collect_and_analyze(args.collect)
    elif args.annotate:
        annotate_interactive(args.annotate)
    elif args.compute:
        compute_metrics(args.compute)
    else:
        # Par défaut : collecter 15 emails
        collect_and_analyze(15)