# TT Mail Assistant

Mobile web app and backend for an intelligent email assistant. The app lets a user connect Gmail, lets Agent 1 analyse and draft replies, sends the draft to Agent 2 for verification, then either auto-sends or asks the user to review depending on the project rules.

Read `Architecture.md` before changing architecture or business rules. It is the full project context and specification.

## Project Structure

```text
TT-Mail-Assistant/
|-- ai-email-agent/      # Agent 1: Gmail tools, LangGraph/LangChain agent, FastAPI wrapper
|-- ai-email-agent-social-media/ # Sentiment agent for future social media analysis
|-- backend/             # FastAPI backend used by the mobile app
|-- frontend/            # Flutter mobile/web app
|-- jury-agent/          # Agent 2 placeholder API; replace with teammate's real Jury Agent
|-- conception/          # UML, sequence diagrams, architecture diagrams, wireframes
|-- Maquette/            # UI mockups
|-- docker-compose.yml   # Local infrastructure: backend, agents, PostgreSQL, Redis
|-- .env.example         # Example environment variables, safe to commit
|-- .gitignore           # Keeps secrets, build output, venvs, and caches out of Git
`-- GEMINI.md            # Main project specification for humans and AI assistants
```

## Required Tools

Install these before setup:

- Git
- Docker Desktop
- Flutter SDK
- Python 3.11
- Ollama installed locally on your PC
- Llama model for Ollama:

```powershell
ollama pull llama3.1
```

The project does not run Ollama inside Docker because the model is large. Docker containers connect to your local Ollama using `host.docker.internal`.

## First Setup

Clone the repository:

```powershell
git clone https://github.com/fouratjebali/tt-mobile-app.git
cd tt-mobile-app
```

Create your local environment file:

```powershell
Copy-Item .env.example .env
```

Edit `.env` if needed. Do not commit `.env`, Gmail credentials, tokens, or local build files.

Start Ollama locally:

```powershell
ollama serve
```

In another terminal, verify Ollama is reachable:

```powershell
curl http://localhost:11434/api/tags
```

Build and start the backend services:

```powershell
docker compose build
docker compose up
```

Useful API URLs:

- Backend docs: `http://localhost:8000/docs`
- Backend health: `http://localhost:8000/api/v1/health`
- Agent 1 health: `http://localhost:8001/health`
- Jury Agent health: `http://localhost:8002/health`
- Social sentiment agent health: `http://localhost:8003/health`

## Flutter Setup

Open a new terminal:

```powershell
cd frontend
flutter pub get
flutter doctor
flutter run
```

For web:

```powershell
flutter run -d chrome
```

For Android, make sure Android Studio and an emulator/device are configured.

## Backend Development

Backend entrypoint:

```text
backend/main.py
```

Main backend package:

```text
backend/app/
|-- api/v1/routes/       # FastAPI route files
|-- core/                # Settings/config
|-- db/                  # Database session setup
|-- models/              # Future SQLAlchemy models
|-- repositories/        # Future database repositories
|-- schemas/             # Pydantic request/response models
|-- services/            # Business logic and agent proxy services
`-- utils/               # Shared helpers
```

Current backend routes:

- `GET /api/v1/health`
- `POST /api/v1/agent/chat`
- `POST /api/v1/jury/verify`
- `POST /api/v1/sentiment/analyze`

## Agent 1 Development

Agent 1 lives in:

```text
ai-email-agent/
```

Important files:

- `api.py`: FastAPI wrapper used by Docker Compose
- `main.py`: original interactive CLI
- `agent/agent.py`: LangGraph ReAct agent
- `agent/tools.py`: Gmail and email tools
- `agent/chains.py`: classification, priority, summary, reply chains
- `gmail/`: Gmail reader/sender integration
- `tests/`: pytest tests

Agent 1 expects Ollama at:

```text
http://host.docker.internal:11434
```

When running Agent 1 outside Docker, it can use:

```text
http://127.0.0.1:11434
```

## Jury Agent

`jury-agent/` currently contains a placeholder API:

- `GET /health`
- `POST /verify`

It returns a `PENDING` verdict until the real Agent 2 implementation is added.

Expected Jury response contract:

```json
{
  "verdict": "VALIDATED | REJECTED | PENDING",
  "confidenceScore": 0.0,
  "comment": "Explanation of the verdict"
}
```

## Social Sentiment Agent

The future social media sentiment feature lives in:

```text
ai-email-agent-social-media/
```

It is exposed in Docker Compose as:

- Direct agent health: `GET http://localhost:8003/health`
- Direct sentiment analysis: `POST http://localhost:8003/sentiment/analyze`
- Backend proxy: `POST http://localhost:8000/api/v1/sentiment/analyze`

Example request through the backend:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/api/v1/sentiment/analyze `
  -ContentType "application/json" `
  -Body '{"text":"Votre service est vraiment nul"}'
```

The first sentiment request can be slow because the Hugging Face model is downloaded and cached. Docker Compose stores that cache in the `sentiment_agent_cache` volume.

## Rules For Everyone

- Never commit `.env`.
- Never commit `credentials.json`.
- Never commit `token.json`.
- Never commit `venv/`, `.dart_tool/`, `frontend/build/`, or cache folders.
- Keep Agent 2 as a black-box service. Use only its API contract.
- Do not bypass the auto-send rule from `GEMINI.md`.
- Flutter ViewModels should call UseCases, not DataSources directly.
- Domain layer should not depend on Presentation or Data.

## Common Git Workflow

Before starting work:

```powershell
git pull
```

Create a branch:

```powershell
git checkout -b feature/your-feature-name
```

Check files before committing:

```powershell
git status --short
```

Commit:

```powershell
git add .
git commit -m "Describe your change"
```

Push your branch:

```powershell
git push -u origin feature/your-feature-name
```

Then open a pull request on GitHub.

## Troubleshooting

If Agent 1 cannot reach Ollama from Docker, make sure Ollama is running on your host:

```powershell
curl http://localhost:11434/api/tags
```

If needed, allow Ollama to listen for Docker connections:

```powershell
setx OLLAMA_HOST "0.0.0.0:11434"
```

Restart your terminal and Ollama after changing that variable.

If Docker fails with a pipe or engine error, start Docker Desktop first.

If Flutter packages are missing:

```powershell
cd frontend
flutter clean
flutter pub get
```
