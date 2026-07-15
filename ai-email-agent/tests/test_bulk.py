import json
import pytest
from unittest.mock import patch, MagicMock
from agent.bulk_generator import BulkEmailGenerator, Recipient, GeneratedEmail
from agent.memory import ConversationMemory
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage


# ----------------------------------------------------------
# Tests BulkEmailGenerator
# ----------------------------------------------------------

def test_recipient_dataclass():
    """Recipient doit stocker les données correctement."""
    r = Recipient(
        name="Alice",
        email="alice@test.com",
        role="Manager",
        context="Gère le projet X"
    )
    assert r.name  == "Alice"
    assert r.email == "alice@test.com"
    assert r.role  == "Manager"


def test_generated_email_default_status():
    """Un GeneratedEmail doit avoir status=pending par défaut."""
    r  = Recipient("Bob", "bob@test.com", "Dev", "Backend")
    ge = GeneratedEmail(
        recipient=r,
        subject="Test",
        body="Hello Bob",
        personalization_note="Mentioned backend role"
    )
    assert ge.status     == "pending"
    assert ge.error      == ""
    assert ge.message_id == ""


def test_generate_one_calls_llm():
    """generate_one doit appeler la chain et parser le résultat."""
    mock_chain_result = json.dumps({
        "subject": "Réunion Q3 - Alice",
        "body":    "Bonjour Alice, en tant que chef de projet...",
        "personalization_note": "Mentioned project manager role"
    })

    with patch.object(BulkEmailGenerator, '__init__',
                      lambda self: None):
        gen = BulkEmailGenerator.__new__(BulkEmailGenerator)
        gen._chain = MagicMock()
        gen._chain.invoke.return_value = mock_chain_result
        # patch LLM init
        from langchain_ollama import OllamaLLM
        gen.llm = MagicMock()

        r      = Recipient("Alice", "alice@co.com", "Chef de projet", "Projet X")
        result = gen.generate_one(r, "Réunion Q3 mercredi")

        assert result.subject == "Réunion Q3 - Alice"
        assert "Alice" in result.body
        assert result.status  == "pending"


def test_results_to_json():
    """results_to_json doit retourner un JSON valide."""
    r  = Recipient("Alice", "alice@co.com", "Manager", "ctx")
    ge = GeneratedEmail(
        recipient=r,
        subject="Test",
        body="Body test content here",
        personalization_note="note",
        status="sent",
        message_id="msg123"
    )

    with patch.object(BulkEmailGenerator, '__init__', lambda self: None):
        gen = BulkEmailGenerator.__new__(BulkEmailGenerator)
        result_str = gen.results_to_json([ge])
        data       = json.loads(result_str)

        assert data["total"]         == 1
        assert data["sent"]          == 1
        assert data["errors"]        == 0
        assert data["results"][0]["recipient"] == "Alice"
        assert data["results"][0]["status"]    == "sent"


# ----------------------------------------------------------
# Tests ConversationMemory
# ----------------------------------------------------------

def test_memory_add_messages():
    """La mémoire doit stocker les messages dans l'ordre."""
    mem = ConversationMemory()
    mem.add_human("Hello agent")
    mem.add_ai("Hello user, how can I help?")
    mem.add_human("Read my emails")

    assert len(mem.messages) == 3
    assert isinstance(mem.messages[0], HumanMessage)
    assert isinstance(mem.messages[1], AIMessage)
    assert isinstance(mem.messages[2], HumanMessage)


def test_memory_turn_count():
    """Le compteur de tours doit s'incrémenter à chaque message humain."""
    mem = ConversationMemory()
    assert mem.turn_count == 0
    mem.add_human("Message 1")
    assert mem.turn_count == 1
    mem.add_human("Message 2")
    assert mem.turn_count == 2


def test_memory_get_full_history_starts_with_system():
    """get_full_history doit toujours commencer par un SystemMessage."""
    mem = ConversationMemory()
    mem.add_human("Hello")
    mem.add_ai("Hi!")

    history = mem.get_full_history()
    assert isinstance(history[0], SystemMessage)
    assert len(history) == 3  # System + Human + AI


def test_memory_clear():
    """clear() doit réinitialiser complètement la mémoire."""
    mem = ConversationMemory()
    mem.add_human("msg1")
    mem.add_ai("resp1")
    mem.add_human("msg2")

    mem.clear()

    assert len(mem.messages) == 0
    assert mem.turn_count    == 0


def test_memory_should_summarize():
    """should_summarize doit retourner True quand MAX_MESSAGES est dépassé."""
    mem = ConversationMemory()
    mem.MAX_MESSAGES = 5

    for i in range(6):
        mem.add_human(f"Message {i}")

    assert mem.should_summarize() is True


def test_memory_display_stats():
    """display_stats doit retourner les bonnes métriques."""
    mem = ConversationMemory()
    mem.add_human("Hello")
    mem.add_ai("Hi")
    mem.add_human("How are you?")

    stats = mem.display_stats()
    assert stats["turns"]          == 2
    assert stats["human_messages"] == 2
    assert stats["ai_messages"]    == 1
    assert stats["total_messages"] == 3