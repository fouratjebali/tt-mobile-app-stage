
# AI Email Agent

Intelligent workflow assistant for automated email management using
LangChain, LangGraph, and a local LLM (Ollama + Llama 3.1).

Developed as part of an apprenticeship internship at
**Tunisie Télécom — Direction Régionale de Sfax**.

---

## Features

- **Gmail Integration** — connects to Gmail via OAuth 2.0
- **Automatic Classification** — RECLAMATION / INFORMATION / SUPPORT / COMMERCIAL
- **Priority Detection** — URGENT / NORMAL / LOW with urgency score (1-10)
- **Email Summarization** — 2-sentence summary + required action
- **Reply Generation** — professional reply in the email's language
- **Bulk Personalized Email** — sends different content to N recipients
- **Conversational Memory** — remembers context across messages
- **Evaluation System** — measures classification accuracy with metrics

---

## Tech Stack

| Layer          | Technology                        |
|----------------|-----------------------------------|
| LLM            | Ollama + Llama 3.1 (8B) — local   |
| Agent          | LangGraph (ReAct pattern)         |
| Chains         | LangChain 0.2.16                  |
| Gmail API      | Google API Python Client          |
| Auth           | OAuth 2.0                         |
| Language       | Python 3.11                       |
| CLI            | Rich                              |
| Tests          | Pytest                            |

---

## Project Structure
ai-email-agent/
├── agent/
│   ├── agent.py          # ReAct agent with LangGraph
│   ├── bulk_generator.py # Personalized bulk email
│   ├── chains.py         # 4 LangChain NLP chains
│   ├── logger.py         # Analysis logging system
│   ├── memory.py         # Conversational memory
│   ├── parser.py         # Robust JSON parser
│   ├── pipeline.py       # Full analysis pipeline
│   ├── prompts.py        # All LLM prompts
│   └── tools.py          # 9 agent tools
├── auth/
│   └── gmail_auth.py     # Gmail OAuth 2.0
├── config/
│   └── settings.py       # Configuration
├── data/
│   ├── evaluate.py       # Evaluation script
│   └── training/         # Evaluation datasets
├── gmail/
│   ├── reader.py         # Read emails
│   └── sender.py         # Send emails
├── tests/                # Pytest test suite
├── demo.py               # Full demo script
├── main.py               # Interactive CLI
└── requirements.txt

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

```bash
python main.py
```

Le script execute 3 checks:
1. Connexion Gmail + lecture de quelques emails
2. Connexion LLM via Ollama
3. Analyse d'un email via prompt

## 9) Tester sur une nouvelle machine

Commande standard:

```bash
pytest -q
```

Etat actuel:
- Les fichiers `tests/test_agent.py` et `tests/test_reader.py` sont vides.
- `pytest` peut donc retourner "no tests ran" pour le moment.

Pour valider le setup aujourd'hui, utiliser `python main.py` comme smoke test principal.

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
