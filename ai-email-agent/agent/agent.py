from typing import Annotated, TypedDict
from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, SystemMessage, BaseMessage, AIMessage
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode, tools_condition
from agent.tools import ALL_TOOLS
from agent.memory import ConversationMemory, SYSTEM_PROMPT_WITH_MEMORY
from config.settings import settings


# ----------------------------------------------------------
# État du graphe
# ----------------------------------------------------------
class AgentState(TypedDict):
    messages: Annotated[list, add_messages]


# ----------------------------------------------------------
# Agent principal avec mémoire
# ----------------------------------------------------------
class EmailAgent:
    """
    Agent ReAct pour la gestion des emails avec mémoire conversationnelle.
    """

    def __init__(self):
        self.llm = ChatOllama(
            base_url=settings.OLLAMA_BASE_URL,
            model=settings.OLLAMA_MODEL,
            temperature=0.1,
            num_predict=settings.OLLAMA_NUM_PREDICT,
            client_kwargs={"timeout": settings.OLLAMA_TIMEOUT_SECONDS},
        )
        self.llm_with_tools = self.llm.bind_tools(ALL_TOOLS)
        self.memory = ConversationMemory()
        self.graph  = self._build_graph()

    def _agent_node(self, state: AgentState) -> AgentState:
        """Nœud LLM : raisonne et décide de l'action suivante."""
        messages = state["messages"]

        # Injecter le system prompt s'il n'est pas encore là
        if not any(isinstance(m, SystemMessage) for m in messages):
            messages = [SystemMessage(content=SYSTEM_PROMPT_WITH_MEMORY)] + messages

        response = self.llm_with_tools.invoke(messages)

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

    def _build_graph(self) -> StateGraph:
        """Construit le graphe LangGraph."""
        builder = StateGraph(AgentState)
        builder.add_node("agent", self._agent_node)
        builder.add_node("tools", ToolNode(tools=ALL_TOOLS))
        builder.add_edge(START, "agent")
        builder.add_conditional_edges("agent", tools_condition)
        builder.add_edge("tools", "agent")
        return builder.compile()

    def chat(self, user_message: str) -> str:
        """
        Envoie un message à l'agent en conservant la mémoire.
        C'est la méthode principale pour la conversation continue.

        Args:
            user_message : instruction de l'utilisateur

        Returns:
            Réponse finale de l'agent
        """
        # Résumer si l'historique est trop long
        if self.memory.should_summarize():
            self.memory.summarize()

        # Ajouter le message utilisateur à la mémoire
        self.memory.add_human(user_message)

        # Construire l'état initial avec TOUT l'historique
        initial_state = {"messages": self.memory.get_full_history()}
        initial_message_count = len(initial_state["messages"])

        # Lancer le graphe
        final_state = self.graph.invoke(
            initial_state,
            config={"recursion_limit": 30},
        )

        # Extraire la réponse finale
        last_message = final_state["messages"][-1]
        response     = last_message.content

        # Sauvegarder tous les nouveaux messages de ce tour dans la mémoire
        for message in final_state["messages"][initial_message_count:]:
            self.memory.add_message(message)

        # Si le dernier message n'était pas une réponse texte, conserver au moins
        # une trace lisible du résultat final.
        return response

    def stream_chat(self, user_message: str):
        """
        Version streaming de chat() — affiche chaque étape en temps réel.

        Yields:
            Tuples (node_name, message)
        """
        if self.memory.should_summarize():
            self.memory.summarize()

        self.memory.add_human(user_message)

        initial_state = {"messages": self.memory.get_full_history()}
        final_response = ""
        turn_messages: list[BaseMessage] = []

        for event in self.graph.stream(
            initial_state,
            config={"recursion_limit": 30},
        ):
            for node_name, state_update in event.items():
                messages = state_update.get("messages", [])
                for msg in messages:
                    content    = getattr(msg, "content", "")
                    tool_calls = getattr(msg, "tool_calls", [])
                    if content and not tool_calls and node_name == "agent":
                        final_response = content
                    turn_messages.append(msg)
                    yield node_name, msg

        for message in turn_messages:
            self.memory.add_message(message)

        if not final_response and len(turn_messages) > 0:
            final_response = getattr(turn_messages[-1], "content", "")

    def reset_memory(self) -> None:
        """Réinitialise la mémoire (nouvelle conversation)."""
        self.memory.clear()

    # Alias pour compatibilité Day 3
    def run(self, instruction: str) -> str:
        return self.chat(instruction)

    def stream(self, instruction: str):
        return self.stream_chat(instruction)