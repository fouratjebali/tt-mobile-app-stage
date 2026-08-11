
# AI Email Agent

Intelligent workflow assistant for automated email management using
LangChain, LangGraph, and a local LLM (Ollama + Llama 3.1).

Developed as part of an apprenticeship internship at
**Tunisie Telecom - Direction Regionale de Sfax**.

---

## Features

- **Gmail Integration** - connects to Gmail via OAuth 2.0
- **Automatic Classification** - RECLAMATION / INFORMATION / SUPPORT / COMMERCIAL
- **Priority Detection** - URGENT / NORMAL / LOW with urgency score (1-10)
- **Email Summarization** - 2-sentence summary + required action
- **Reply Generation** - professional reply in the email's language
- **Safe Email Sending** - drafts first, then sends only after explicit confirmation
- **Bulk Personalized Email** - generates different content for N recipients, with dry-run enabled by default
- **Conversational Memory** - remembers context across messages
- **Evaluation System** - measures classification accuracy with metrics

---

## Tech Stack

| Layer          | Technology                        |
|----------------|-----------------------------------|
| LLM            | Ollama + Llama 3.1 (8B) - local   |
| Agent          | LangGraph (ReAct pattern)         |
| Chains         | LangChain 0.2.16                  |
| Gmail API      | Google API Python Client          |
| Auth           | OAuth 2.0                         |
| Language       | Python 3.11                       |
| CLI            | Rich                              |
| Tests          | Pytest                            |

---

## Project Structure
```text
ai-email-agent/
|-- agent/
|   |-- agent.py          # ReAct agent with LangGraph
|   |-- bulk_generator.py # Personalized bulk email
|   |-- chains.py         # 4 LangChain NLP chains
|   |-- logger.py         # Analysis logging system
|   |-- memory.py         # Conversational memory
|   |-- parser.py         # Robust JSON parser
|   |-- pipeline.py       # Full analysis pipeline
|   |-- prompts.py        # All LLM prompts
|   `-- tools.py          # 9 agent tools
|-- auth/
|   `-- gmail_auth.py     # Gmail OAuth 2.0
|-- config/
|   `-- settings.py       # Configuration
|-- data/
|   |-- evaluate.py       # Evaluation script
|   `-- training/         # Evaluation datasets
|-- gmail/
|   |-- reader.py         # Read emails
|   `-- sender.py         # Send emails
|-- tests/                # Pytest test suite
|-- demo.py               # Full demo script
|-- main.py               # Interactive CLI
`-- requirements.txt
```

## Installation
## 1) Pre-requis

- Python 3.11 recommande
- Un compte Gmail
- Un projet Google Cloud avec Gmail API active
- Ollama installe localement
- Le modele Ollama telecharge (par defaut: `llama3.1`)

## 2) Recuperer le projet

```bash
git clone <URL_DU_REPO>
cd ai-email-agent
```

## 3) Creer et activer un environnement virtuel

### Windows (PowerShell)

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### macOS / Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 4) Installer les dependances

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

## 5) Configurer Ollama

1. Installer Ollama: https://ollama.com/download
2. Telecharger le modele attendu:

```bash
ollama pull llama3.1
```

3. Verifier que le service tourne (en local, port 11434).

## 6) Configurer Gmail OAuth

Le projet utilise OAuth via le fichier `credentials.json` a la racine.

1. Aller sur Google Cloud Console
2. Creer (ou utiliser) un projet
3. Activer Gmail API
4. Creer des identifiants OAuth 2.0 de type "Desktop app"
5. Telecharger le JSON OAuth et le placer a la racine sous le nom:

```text
credentials.json
```

### Important

- `token.json` est genere automatiquement apres la premiere authentification.
- Ne pas versionner ni partager `credentials.json` et `token.json`.
- Si `token.json` est invalide/expire, le supprimer puis relancer `python main.py`.

## 7) Configurer le fichier .env

Creer un fichier `.env` a la racine avec uniquement les cles utiles au projet:

```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1
MAX_EMAILS=10
LOG_LEVEL=INFO
client_id=
client_secret=
```

Note: eviter d'ajouter des variables non attendues dans `.env`, sinon le chargement de config peut echouer selon la configuration pydantic.

## 8) Lancer le projet

### API

```bash
uvicorn api:app --reload --port 8001
```

Useful URLs:

- `http://127.0.0.1:8001/` - service index and route list
- `http://127.0.0.1:8001/docs` - Swagger UI
- `http://127.0.0.1:8001/health` - basic health response
- `http://127.0.0.1:8001/ready` - dependency configuration summary
- `http://127.0.0.1:8001/emails` - latest unread email previews

Every API response includes `X-Request-ID`. Clients can also send their own
`X-Request-ID` header to correlate mobile/backend logs. API errors use this
shape:

```json
{
  "status": "error",
  "error": "internal_server_error",
  "detail": "LLM unavailable",
  "request_id": "client-or-generated-request-id"
}
```

### CLI

```bash
python main.py
```

The CLI starts an interactive agent session.

### Manual test runner

Use this script when you want to control tests from the terminal:

```bash
python manual_test.py
```

It lets you test Gmail auth, read latest unread emails, analyze unread emails,
chat with the agent using custom prompts, and call individual tools. Send tools
run in preview mode unless `confirm_send=True` is explicitly used in code.

For a faster smoke test:

```bash
python manual_test.py --quick
```

## 9) Tester sur une nouvelle machine

Install dependencies in a virtual environment first, then run:

```bash
python -m pytest -q
```

If dependencies are not installed, `pytest` or `fastapi` imports will fail.

## 10) Probleme frequents

### Erreur OAuth / navigateur ne s'ouvre pas

- Verifier `credentials.json` (format OAuth Desktop)
- Relancer la commande et terminer l'authentification web

### Erreur Gmail API (403 / access denied)

- Verifier que Gmail API est bien active sur le projet Google Cloud
- Verifier le compte Google utilise pendant le consentement

### Erreur Ollama (connexion refusee)

- Verifier qu'Ollama est lance
- Verifier `OLLAMA_BASE_URL`
- Verifier que le modele existe (`ollama list`)

### Erreur de module Python introuvable

- Verifier que l'environnement virtuel est active
- Reinstaller: `pip install -r requirements.txt`

## 11) Structure utile du projet

```text
ai-email-agent/
	main.py                # Script principal de verification setup
	requirements.txt       # Dependances Python
	auth/gmail_auth.py     # Auth Gmail OAuth
	gmail/reader.py        # Lecture d'emails
	gmail/sender.py        # Envoi d'emails
	config/settings.py     # Variables de configuration (.env)
	tests/                 # Squelettes de tests (a completer)
```

## 12) Commandes rapides (copier/coller)

### Windows PowerShell

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
ollama pull llama3.1
python main.py
pytest -q
```

### macOS / Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ollama pull llama3.1
python main.py
pytest -q
```
