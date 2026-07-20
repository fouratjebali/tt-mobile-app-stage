# Social Media Sentiment Agent

Agent IA de veille et d'analyse de sentiment des commentaires et interactions
reçus sur les réseaux sociaux, connecté à Gmail (via OAuth 2.0) et utilisant
un LLM local (Ollama + Llama 3.1) pour l'orchestration, combiné à une
bibliothèque dédiée (Hugging Face `transformers`) pour l'analyse de sentiment.

Développé dans le cadre d'un stage à
**Tunisie Télécom **.

---

## Fonctionnalités

- **Lecture des notifications réseaux sociaux** — via les e-mails Gmail reçus (Facebook, ...)
- **Extraction structurée** — plateforme, auteur, texte du commentaire, lien du post
- **Analyse de sentiment** — POSITIVE / NEUTRAL / NEGATIVE avec score de confiance, via un modèle dédié (pas le LLM)
- **Multilingue** — français, anglais, arabe, etc.
- **Mémoire conversationnelle** — l'agent se souvient du contexte entre les messages
- **Outil de debug intégré** — pour diagnostiquer un problème d'extraction sur un e-mail précis

---

## Tech Stack

| Couche              | Technologie                                          |
|---------------------|-------------------------------------------------------|
| LLM (orchestration)  | Ollama + Llama 3.1 (8B) — local                      |
| Agent                | LangGraph (ReAct pattern)                             |
| Analyse de sentiment | Hugging Face `transformers` (cardiffnlp/twitter-xlm-roberta-base-sentiment) |
| Gmail API            | Google API Python Client                              |
| Auth                 | OAuth 2.0                                              |
| Langage              | Python 3.11+                                           |
| CLI                  | Rich                                                   |
| Automatisation Facebook → Gmail | Zapier                                      |

---

## Structure du projet

```text
ai-email-agent-main/
├── agent2/
│   ├── __init__.py
│   ├── agent.py            # Agent ReAct (LangGraph) + mémoire de conversation
│   ├── sentiment.py         # Analyse de sentiment (bibliothèque transformers)
│   ├── social_reader.py     # Lecture + extraction des notifications Gmail
│   └── tools.py             # 4 outils exposés au LLM
├── auth/
│   └── gmail_auth.py         # Authentification OAuth 2.0 Gmail
├── config/
│   └── settings.py            # Configuration (.env)
├── gmail/
│   ├── reader.py               # Lecture d'e-mails
│   └── sender.py                # Envoi d'e-mails
├── main_agent2.py                 # CLI interactive
├── requirements.txt                # Dépendances de base (langchain, langgraph, rich, google-api...)
├── requirements_agent2.txt          # Dépendances supplémentaires (transformers, torch, sentencepiece)
├── credentials.json                  # Identifiants OAuth Google (à ne jamais partager)
├── token.json                          # Token généré après 1ère authentification (à ne jamais partager)
└── .env                                  # Variables de configuration
```

---

## Installation

### 1) Pré-requis

- Python 3.11+ (accessible via `py` sur Windows si `python` pointe vers une
  ancienne version)
- Un compte Gmail
- Un projet Google Cloud avec l'API Gmail activée
- Ollama installé localement, avec le modèle `llama3.1` téléchargé
- Un compte Zapier (plan gratuit) 

### 2) Créer et activer l'environnement virtuel

**Windows (PowerShell)**
```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
```

**macOS / Linux**
```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 3) Installer les dépendances

```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements_agent2.txt
```

⚠️ `transformers` + `torch` représentent environ 2-3 Go à télécharger. Le tout
premier lancement téléchargera aussi le modèle de sentiment (~1 Go, mis en
cache ensuite).

### 4) Configurer Ollama

```powershell
ollama pull llama3.1
ollama list   # vérifier que llama3.1 apparaît bien
```

### 5) Configurer l'authentification Gmail (OAuth)

1. Google Cloud Console → créer/sélectionner un projet
2. Activer l'API Gmail
3. Configurer l'écran de consentement OAuth (type Externe, ajouter ton
   adresse comme utilisateur de test)
4. Créer un identifiant OAuth de type **Application de bureau**
5. Télécharger le JSON, le renommer `credentials.json`, le placer à la racine

`token.json` sera généré automatiquement après la première authentification
(une fenêtre de navigateur s'ouvrira au premier lancement).

### 6) Configurer le fichier `.env`

```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1
MAX_EMAILS=10
LOG_LEVEL=INFO
client_id=
client_secret=
```

### 7) (Optionnel) Configurer Zapier pour relayer les commentaires Facebook vers Gmail

Les nouvelles Pages Facebook n'envoient plus nativement de notification par
e-mail pour les commentaires. Solution de contournement gratuite :

1. Crée un compte sur https://zapier.com (plan gratuit, pas de carte bancaire)
2. Crée un Zap : déclencheur **"New Comment in Facebook Pages"** → action
   **"Send Email"** (Gmail)
3. Dans le corps de l'e-mail, insère la variable dynamique **"Comment Message"**
   (pas de texte tapé à la main, pour que le vrai texte du commentaire soit transmis)
4. Publie le Zap

---

## Lancer l'agent

```powershell
python main_agent2.py
```

### Commandes disponibles dans l'interface

| Commande | Effet |
|---|---|
| `quit` | Quitter |
| `reset` | Effacer la mémoire de conversation |
| `help` | Réafficher l'aide |

### Exemples d'instructions

```
Read social media notifications with query "subject:(commented OR comment)" and max_results 10
Call the analyze_sentiment tool on this exact text: "Votre service est vraiment nul, je suis déçu"
Call analyze_notification_sentiment on email_id [email_id d'un résultat précédent]
Show me the raw email content for email_id [email_id]
```

⚠️ **Règle importante** : formule toujours **une seule action par message**
("Read..." OU "Analyze...", jamais les deux enchaînés, ni "for each...").
Le modèle local (Llama 3.1 8B) n'enchaîne pas fiablement plusieurs appels
d'outils dans une seule instruction.

---

## Les 4 outils de l'agent

| Outil | Rôle |
|---|---|
| `analyze_sentiment(text)` | Analyse un texte donné directement |
| `analyze_notification_sentiment(email_id)` | Analyse le sentiment d'un commentaire via son ID Gmail (le plus fiable, gère les emojis) |
| `read_social_notifications(query, max_results)` | Lit les notifications Gmail et les structure |
| `debug_raw_email(email_id)` | Affiche le contenu brut d'un e-mail pour diagnostiquer un problème d'extraction |

---

## Problèmes fréquents

### Erreur OAuth / navigateur ne s'ouvre pas
- Vérifier `credentials.json` (format OAuth Desktop)
- Relancer la commande et terminer l'authentification web

### Erreur Gmail API (403 / accès refusé)
- Vérifier que l'API Gmail est bien activée sur le projet Google Cloud
- Vérifier le compte Google utilisé pendant le consentement

### Erreur Ollama (connexion refusée)
- Vérifier qu'Ollama est lancé (`ollama list`)
- Vérifier `OLLAMA_BASE_URL` dans `.env`

### Module Python introuvable
- Vérifier que l'environnement virtuel est activé (`(.venv)` visible)
- Réinstaller : `pip install -r requirements.txt` puis `pip install -r requirements_agent2.txt`

### L'agent invente des résultats au lieu d'appeler un outil
- Limite connue du LLM local sur les instructions combinées ("for each...")
- Toujours formuler une seule action par message (voir section "Lancer l'agent")
