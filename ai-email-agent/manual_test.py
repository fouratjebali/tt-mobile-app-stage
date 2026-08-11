import argparse
import json
import traceback
from typing import Callable


MENU = """
AI Email Agent Manual Test Runner

1. Auth check Gmail OAuth
2. Read latest unread emails
3. Analyze latest unread emails
4. Chat with agent using prompts
5. Test individual tools
6. Reset agent memory
7. Show agent memory stats
0. Exit
"""


def print_json(data) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False))


def ask_int(prompt: str, default: int, minimum: int = 1, maximum: int = 50) -> int:
    raw = input(f"{prompt} [{default}]: ").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError:
        print(f"Invalid number. Using {default}.")
        return default
    return max(minimum, min(maximum, value))


def ask_text(prompt: str, default: str = "") -> str:
    raw = input(f"{prompt}{f' [{default}]' if default else ''}: ").strip()
    return raw or default


def safe_run(title: str, action: Callable[[], None]) -> None:
    print(f"\n--- {title} ---")
    try:
        action()
    except KeyboardInterrupt:
        print("\nCancelled.")
    except Exception as exc:
        print(f"ERROR: {exc}")
        traceback.print_exc()


def auth_check() -> None:
    from auth.gmail_auth import get_gmail_service

    print("Starting Gmail OAuth check. A browser may open if token.json is missing.")
    service = get_gmail_service()
    profile = service.users().getProfile(userId="me").execute()
    print_json({
        "status": "ok",
        "email_address": profile.get("emailAddress"),
        "messages_total": profile.get("messagesTotal"),
        "threads_total": profile.get("threadsTotal"),
    })


def read_latest_unread() -> list:
    from gmail.reader import fetch_emails

    max_results = ask_int("How many unread emails should I read?", default=5)
    emails = fetch_emails(max_results=max_results, query="is:unread")

    if not emails:
        print_json({"status": "empty", "count": 0, "emails": []})
        return []

    rows = []
    for email in emails:
        rows.append({
            "id": email.id,
            "subject": email.subject,
            "sender": email.sender,
            "date": email.date,
            "is_read": email.is_read,
            "body_preview": email.short_body(180),
        })

    print_json({"status": "ok", "count": len(rows), "emails": rows})
    return emails


def analyze_latest_unread() -> None:
    from agent.pipeline import EmailPipeline

    emails = read_latest_unread()
    if not emails:
        return

    pipeline = EmailPipeline()
    results = []
    for email in emails:
        print(f"\nAnalyzing: {email.subject}")
        result = pipeline.analyze(email)
        data = result.display_dict()
        data["email_id"] = email.id
        data["is_urgent"] = result.is_urgent()
        data["needs_reply"] = result.needs_reply()
        results.append(data)
        print_json(data)

    print_json({"status": "ok", "analyzed": len(results)})


def get_or_create_agent(state: dict):
    if state.get("agent") is None:
        from agent.agent import EmailAgent

        print("Loading agent. This may take a moment if Ollama is warming up.")
        state["agent"] = EmailAgent()
    return state["agent"]


def chat_with_agent(state: dict) -> None:
    agent = get_or_create_agent(state)
    print("\nType prompts for the agent. Commands: /back, /reset, /unread")

    while True:
        prompt = input("\nYou: ").strip()
        if not prompt:
            continue
        if prompt.lower() == "/back":
            break
        if prompt.lower() == "/reset":
            agent.reset_memory()
            print("Memory reset.")
            continue
        if prompt.lower() == "/unread":
            prompt = "Read my latest unread emails and summarize the most important ones."

        final_response = ""
        for node_name, message in agent.stream_chat(prompt):
            content = getattr(message, "content", "")
            tool_calls = getattr(message, "tool_calls", [])
            if tool_calls:
                for call in tool_calls:
                    name = call.get("name", "?")
                    args = call.get("args", {})
                    print(f"TOOL -> {name} {json.dumps(args, ensure_ascii=False)}")
            elif node_name == "tools" and content:
                print(f"TOOL <- {content[:400].replace(chr(10), ' ')}")
            elif node_name == "agent" and content:
                final_response = content

        if final_response:
            print(f"\nAgent:\n{final_response}")


def invoke_tool(tool, payload: dict) -> dict:
    raw = tool.invoke(payload)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"status": "raw", "content": raw}


def test_tools() -> None:
    from agent.tools import (
        classify_email,
        get_urgent_emails,
        prioritize_email,
        read_emails,
        send_bulk_email,
        send_single_email,
        summarize_email,
        suggest_reply,
    )

    tool_menu = """
Tool Tests

1. read_emails
2. classify_email
3. prioritize_email
4. summarize_email
5. suggest_reply
6. get_urgent_emails
7. send_single_email preview only
8. send_bulk_email preview only
0. Back
"""

    while True:
        print(tool_menu)
        choice = input("Choose a tool test: ").strip()
        if choice == "0":
            break

        if choice == "1":
            query = ask_text("Gmail query", "is:unread")
            max_results = ask_int("Max results", 5)
            print_json(invoke_tool(read_emails, {"query": query, "max_results": max_results}))
        elif choice in {"2", "3", "4", "5"}:
            email_id = ask_text("Email ID from read_emails output")
            if choice == "2":
                print_json(invoke_tool(classify_email, {"email_id": email_id}))
            elif choice == "3":
                category = ask_text("Category", "UNKNOWN")
                print_json(invoke_tool(prioritize_email, {"email_id": email_id, "category": category}))
            elif choice == "4":
                print_json(invoke_tool(summarize_email, {"email_id": email_id}))
            else:
                category = ask_text("Category", "SUPPORT")
                priority = ask_text("Priority", "NORMAL")
                print_json(invoke_tool(
                    suggest_reply,
                    {"email_id": email_id, "category": category, "priority": priority},
                ))
        elif choice == "6":
            max_results = ask_int("Max unread emails to scan", 10)
            print_json(invoke_tool(get_urgent_emails, {"max_results": max_results}))
        elif choice == "7":
            payload = {
                "to": ask_text("To", "recipient@example.com"),
                "subject": ask_text("Subject", "Manual test"),
                "body": ask_text("Body", "This is a safe preview test."),
            }
            print_json(invoke_tool(send_single_email, payload))
        elif choice == "8":
            recipients = [{
                "to": ask_text("To", "recipient@example.com"),
                "subject": ask_text("Subject", "Manual bulk test"),
                "body": ask_text("Body", "This is a safe bulk preview test."),
            }]
            print_json(invoke_tool(send_bulk_email, {"recipients_json": json.dumps(recipients)}))
        else:
            print("Unknown choice.")


def reset_memory(state: dict) -> None:
    agent = get_or_create_agent(state)
    agent.reset_memory()
    print("Memory reset.")


def show_memory_stats(state: dict) -> None:
    agent = get_or_create_agent(state)
    print_json(agent.memory.display_stats())


def quick_check() -> None:
    safe_run("Auth check Gmail OAuth", auth_check)
    safe_run("Read latest unread emails", read_latest_unread)
    safe_run("Analyze latest unread emails", analyze_latest_unread)


def interactive() -> None:
    state = {"agent": None}
    while True:
        print(MENU)
        choice = input("Choose a test: ").strip()
        if choice == "0":
            print("Goodbye.")
            break
        if choice == "1":
            safe_run("Auth check Gmail OAuth", auth_check)
        elif choice == "2":
            safe_run("Read latest unread emails", read_latest_unread)
        elif choice == "3":
            safe_run("Analyze latest unread emails", analyze_latest_unread)
        elif choice == "4":
            safe_run("Chat with agent", lambda: chat_with_agent(state))
        elif choice == "5":
            safe_run("Test individual tools", test_tools)
        elif choice == "6":
            safe_run("Reset agent memory", lambda: reset_memory(state))
        elif choice == "7":
            safe_run("Show agent memory stats", lambda: show_memory_stats(state))
        else:
            print("Unknown choice.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Manual terminal tester for AI Email Agent.")
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Run auth, unread email read, and unread email analysis checks without the menu.",
    )
    args = parser.parse_args()

    if args.quick:
        quick_check()
    else:
        interactive()


if __name__ == "__main__":
    main()
