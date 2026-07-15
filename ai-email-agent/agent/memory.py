import json
from datetime import datetime
from langchain_core.messages import (
    HumanMessage,
    AIMessage,
    SystemMessage,
    BaseMessage,
)
from langchain_ollama import OllamaLLM
from langchain_core.prompts import PromptTemplate
from agent.prompts import CONVERSATION_SUMMARY_PROMPT
from agent.parser import parser
from config.settings import settings


SYSTEM_PROMPT_WITH_MEMORY = """You are an intelligent email management assistant with access to Gmail.

You have the following tools available:
- read_emails                    : read emails from Gmail (use this first)
- classify_email                 : classify an email by category
- prioritize_email               : determine urgency level
- summarize_email                : generate a short summary
- suggest_reply                  : generate a professional reply
- send_single_email              : send one email
- send_bulk_email                : send emails to multiple recipients
- generate_and_send_bulk_emails  : generate PERSONALIZED emails for each recipient
- get_urgent_emails              : find all urgent emails automatically

IMPORTANT RULES:
1. Always call read_emails first before analysis (unless emails were already read this session).
2. Use email IDs from read_emails results to call other tools.
3. Remember context from previous messages in this conversation.
4. Before sending any email, confirm the content with the user.
5. Think step by step. Use one tool at a time.
6. Respond in the same language the user writes to you.
7. After completing a task, give a clear summary of what was done.
8. If the user says "the ones from before" or "those emails", use context from history.
"""


class ConversationMemory:
    """
    Gère l'historique de la conversation avec l'agent.

    L'historique est une liste de BaseMessage :
      HumanMessage  → ce que l'utilisateur a dit
      AIMessage     → ce que l'agent a répondu
      SystemMessage → le prompt système (ajouté en premier)

    Quand l'historique devient trop long, on le résume automatiquement.
    """

    MAX_MESSAGES = 30       # au-delà, on résume pour économiser les tokens
    SUMMARY_KEEP  = 6       # messages récents à garder après résumé

    def __init__(self):
        self.messages: list[BaseMessage] = []
        self.session_start = datetime.now()
        self.turn_count    = 0
        self._llm = OllamaLLM(
            base_url=settings.OLLAMA_BASE_URL,
            model=settings.OLLAMA_MODEL,
            temperature=0.1,
        )

    def add_human(self, text: str) -> None:
        """Ajoute un message de l'utilisateur."""
        self.messages.append(HumanMessage(content=text))
        self.turn_count += 1

    def add_ai(self, text: str) -> None:
        """Ajoute une réponse de l'agent."""
        self.messages.append(AIMessage(content=text))

    def add_message(self, message: BaseMessage) -> None:
        """Ajoute n'importe quel message LangChain à l'historique."""
        self.messages.append(message)

    def add_system(self, text: str) -> None:
        """Ajoute un message système."""
        self.messages.append(SystemMessage(content=text))

    def get_full_history(self) -> list[BaseMessage]:
        """
        Retourne l'historique complet prêt pour le LLM.
        Le SystemMessage est toujours en premier.
        """
        system = SystemMessage(content=SYSTEM_PROMPT_WITH_MEMORY)
        return [system] + self.messages

    def should_summarize(self) -> bool:
        """Vérifie si l'historique est trop long."""
        return len(self.messages) > self.MAX_MESSAGES

    def summarize(self) -> None:
        """
        Résume les anciens messages pour réduire la taille de l'historique.
        Garde les SUMMARY_KEEP messages les plus récents intacts.
        """
        if len(self.messages) <= self.SUMMARY_KEEP:
            return

        # Séparer ancien et récent
        old_messages   = self.messages[:-self.SUMMARY_KEEP]
        recent_messages = self.messages[-self.SUMMARY_KEEP:]

        # Construire le texte de l'historique à résumer
        history_text = ""
        for msg in old_messages:
            role = "User" if isinstance(msg, HumanMessage) else "Agent"
            history_text += f"{role}: {msg.content[:300]}\n"

        # Appeler le LLM pour résumer
        chain = PromptTemplate.from_template(CONVERSATION_SUMMARY_PROMPT) | self._llm
        raw   = chain.invoke({"history": history_text})
        data  = parser.safe_parse(raw, default={
            "summary": history_text[:500],
            "emails_processed": [],
            "actions_taken": [],
            "pending_actions": [],
        })

        # Créer un message système de résumé
        summary_text = (
            f"[Conversation summary so far]\n"
            f"{data.get('summary', '')}\n"
            f"Emails processed: {', '.join(data.get('emails_processed', []))}\n"
            f"Actions taken: {', '.join(data.get('actions_taken', []))}\n"
            f"Pending: {', '.join(data.get('pending_actions', []))}"
        )

        # Remplacer les vieux messages par le résumé + garder les récents
        self.messages = [SystemMessage(content=summary_text)] + recent_messages
        print(f"  [Memory] Summarized {len(old_messages)} old messages.")

    def clear(self) -> None:
        """Réinitialise complètement la mémoire."""
        self.messages     = []
        self.turn_count   = 0
        self.session_start = datetime.now()

    def display_stats(self) -> dict:
        """Retourne des statistiques sur la mémoire."""
        human_msgs = sum(1 for m in self.messages if isinstance(m, HumanMessage))
        ai_msgs    = sum(1 for m in self.messages if isinstance(m, AIMessage))
        duration   = (datetime.now() - self.session_start).seconds // 60
        return {
            "turns":          self.turn_count,
            "human_messages": human_msgs,
            "ai_messages":    ai_msgs,
            "total_messages": len(self.messages),
            "duration_min":   duration,
        }