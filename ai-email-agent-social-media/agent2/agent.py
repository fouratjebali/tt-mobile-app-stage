"""
Agent 2 : "Jury" + surveillance des réseaux sociaux.

Même pattern ReAct/LangGraph que l'Agent 1 (agent/agent.py), mais avec
un system prompt et une boîte à outils différents (agent2/tools.py).

Rôle :
1. Lire les notifications de réseaux sociaux dans Gmail et analyser leur sentiment.
2. Vérifier ("jury") les réponses générées par l'Agent 1 avant tout envoi.
3. Transmettre le tout à l'admin humain pour validation finale — l'Agent 2
   n'envoie JAMAIS rien directement à un contact externe.
"""

from __future__ import annotations

from typing import Annotated, TypedDict

from langchain_ollama import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode, tools_condition

from agent2.tools import ALL_TOOLS_AGENT2
from config.settings import settings


SYSTEM_PROMPT_AGENT2 = """
You are Agent 2, the "Jury" and social-media monitor of an email/social-media
assistant system.

Your responsibilities:
1. Read social media notifications arriving in Gmail (comments, likes) and run
   sentiment analysis on comments when asked.
2. When asked to review Agent 1's work, act as a strict quality-control jury:
   compare the original message to Agent 1's proposed reply, and flag any issues.
3. After a review, send a summary to the human admin for final approval.
   NEVER send anything directly to an external contact yourself — you only
   ever notify the admin, who has the final decision.

Important rules:
- When you already have an email_id (from a previous read_social_notifications
  call), prefer analyze_notification_sentiment(email_id) over analyze_sentiment(text).
  It fetches and analyzes the comment text directly from Gmail, which is more
  reliable than retyping the text yourself — this matters especially for
  comments containing emojis or special characters, which you may copy incorrectly.
- If the answer to a question is already available in the earlier messages of
  this conversation (e.g. you already read a comment's text earlier), answer
  directly from that context instead of calling a tool again, unless the user
  is explicitly asking for fresh/updated data.

Always use the available tools rather than guessing or inventing information.
Be concise and clear in your final answers.
"""


class AgentState(TypedDict):
    messages: Annotated[list, add_messages]


class JuryAndSocialAgent:
    """Agent 2 : jury + veille des réseaux sociaux."""

    # Nombre max de messages conservés en mémoire avant troncature simple
    # (protection contre une croissance illimitée sur une longue session).
    MAX_HISTORY_MESSAGES = 40

    def __init__(self):
        self.llm = ChatOllama(
            base_url=settings.OLLAMA_BASE_URL,
            model=settings.OLLAMA_MODEL,
            temperature=0.0,  # déterministe : c'est un rôle de contrôle, pas de créativité
            num_predict=getattr(settings, "OLLAMA_NUM_PREDICT", 512),
        )
        self.llm_with_tools = self.llm.bind_tools(ALL_TOOLS_AGENT2)
        self.graph = self._build_graph()
        # Historique persistant entre les tours (corrige le bug d'hallucination :
        # sans ça, chaque instruction repartait de zéro et le LLM inventait des
        # réponses plausibles quand on lui parlait de "ce qu'il a trouvé avant").
        self.history: list = []

    def _agent_node(self, state: AgentState) -> AgentState:
        messages = state["messages"]
        if not any(isinstance(m, SystemMessage) for m in messages):
            messages = [SystemMessage(content=SYSTEM_PROMPT_AGENT2)] + messages

        response = self.llm_with_tools.invoke(messages)

        # Comme pour l'Agent 1 : on ne garde qu'UN SEUL appel d'outil par tour,
        # pour éviter les comportements imprévisibles si le LLM en propose plusieurs.
        tool_calls = getattr(response, "tool_calls", [])
        if len(tool_calls) > 1:
            response = AIMessage(
                content=response.content,
                tool_calls=[tool_calls[0]],
                additional_kwargs=getattr(response, "additional_kwargs", {}),
                response_metadata=getattr(response, "response_metadata", {}),
                id=getattr(response, "id", None),
            )

        return {"messages": [response]}

    def _build_graph(self):
        builder = StateGraph(AgentState)
        builder.add_node("agent", self._agent_node)
        builder.add_node("tools", ToolNode(tools=ALL_TOOLS_AGENT2))
        builder.add_edge(START, "agent")
        builder.add_conditional_edges("agent", tools_condition)
        builder.add_edge("tools", "agent")
        return builder.compile()

    def _truncate_history(self) -> None:
        """Troncature simple : garde les N derniers messages si trop long."""
        if len(self.history) > self.MAX_HISTORY_MESSAGES:
            self.history = self.history[-self.MAX_HISTORY_MESSAGES:]

    def run(self, instruction: str) -> str:
        """Envoie une instruction à l'Agent 2, EN CONSERVANT la mémoire des tours précédents."""
        self.history.append(HumanMessage(content=instruction))
        self._truncate_history()

        initial_state = {"messages": self.history}
        initial_count = len(self.history)

        final_state = self.graph.invoke(initial_state, config={"recursion_limit": 30})

        # Ajoute uniquement les NOUVEAUX messages de ce tour à l'historique
        self.history.extend(final_state["messages"][initial_count:])

        return final_state["messages"][-1].content

    def stream(self, instruction: str):
        """Version streaming : yield (node_name, message), EN CONSERVANT la mémoire."""
        self.history.append(HumanMessage(content=instruction))
        self._truncate_history()

        initial_state = {"messages": self.history}

        for event in self.graph.stream(initial_state, config={"recursion_limit": 30}):
            for node_name, state_update in event.items():
                for msg in state_update.get("messages", []):
                    # Chaque delta de state_update est un NOUVEAU message
                    # (grâce au reducer add_messages) : on l'ajoute directement.
                    self.history.append(msg)
                    yield node_name, msg

    def reset_memory(self) -> None:
        """Réinitialise la mémoire (nouvelle conversation, comme l'Agent 1)."""
        self.history = []
