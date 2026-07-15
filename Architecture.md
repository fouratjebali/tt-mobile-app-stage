# arch.md

> Context file for AI assistants working on this repository. Read this
> file in full before making changes, answering architecture questions,
> or generating code. It reflects the current, agreed state of the
> project as of the design phase handoff to the mobile development team.

---

## 1. Project Overview

**Name:** TT Mail Assistant (working title) — Intelligent Email Management Assistant

**One-liner:** A mobile application that lets a user connect their Gmail
account and have two cooperating AI agents automatically read, classify,
prioritise and reply to their emails — asking the user to intervene only
when an email is urgent or when the agents are not confident enough.

**Context:** Built during a 2-month apprenticeship internship at
**Tunisie Télécom — Direction Régionale de Tunis**, supervised by
**Mme Saïda Rabah**. Team lead: **Fourat Jebali (Elking)**. Two junior
developers report to the team lead for the mobile app build phase:
**Islem** and **Senda**. A separate teammate is building **Agent 2
(Jury Agent)** independently; this repo/context treats it as an external
service with a defined contract.

**Core value proposition:** minimise the time a user spends triaging and
replying to email. The user should only ever open the app to (a) glance
at a dashboard, (b) approve/edit a reply for a genuinely urgent email,
or (c) talk to the agent directly via a chat-style prompt.

---

## 2. The Two-System Split

This project consists of **two systems** that together form the product:

| System | Status | Language/Stack | Owner |
|---|---|---|---|
| **AI Agent Backend** (Agent 1 + tools + chains) | ✅ Built, tested, evaluated | Python 3.11, LangChain, LangGraph, Ollama | Team lead |
| **Jury Agent** (Agent 2) | 🔄 Built separately by teammate | Unknown internals — treated as a black-box API | Teammate |
| **Mobile Application** | 🔜 In development (Sprint 1–4, Islem & Senda) | Flutter or React Native (final choice pending, Clean Architecture applies either way) | Islem, Senda, Team lead |
| **Backend API (FastAPI)** | 🔜 To be built to bridge mobile ↔ agents | Python, FastAPI, PostgreSQL, Redis | Team lead |

Environment setup and Gmail OAuth 2.0 integration are **owned by the team
lead** and are out of scope for Islem/Senda's task list.

---

## 3. Problem Statement & Core Business Rule

> How can we automate email triage and response with AI, while
> guaranteeing that a human still makes the call on anything urgent or
> uncertain — without making the user manage a traditional inbox?

This single rule governs almost every architectural decision in both the
agent and the mobile app. Memorise it — it is referenced throughout this
document as **"the auto-send rule."**

```
AUTO-SEND (no human involved) requires ALL of:
  ✓ priority          != URGENT
  ✓ jury verdict        == VALIDATED
  ✓ jury confidenceScore >= juryConfidenceThreshold   (default 0.80)
  ✓ user.autoProcessingEnabled == true

ESCALATE TO REVIEW (human must act) if ANY of:
  ✗ priority          == URGENT
  ✗ jury verdict        == REJECTED
  ✗ jury confidenceScore <  juryConfidenceThreshold
  ✗ the automatic Gmail send call failed
```

Any feature, screen, or piece of logic that touches "should this be sent
automatically" must implement exactly this rule — do not reinvent it.

---

## 4. AI Agent System (Agent 1) — Fully Built

This is the component with the most concrete, already-implemented code.
Treat its behaviour as a fixed contract that the mobile app and backend
API must integrate with, not something to redesign.

### 4.1 Architecture Summary

```
Interface (CLI)  →  Agent ReAct (LangGraph)  →  9 Tools  →  4 NLP Chains  →  LLM (Ollama)
                            ↓                                                    ↑
                    Conversation Memory                              Gmail API (reader/sender)
```

- **Pattern:** ReAct (Reasoning + Acting) — the LLM alternates between
  *Thought* (decide what to do), *Action* (call a tool), and
  *Observation* (read the tool's result), looping until it can produce a
  final answer (max 30 iterations).
- **Orchestration:** LangGraph `StateGraph` with two nodes:
  `agent_node` (calls the LLM with tools bound) and `tools_node`
  (executes whichever tool the LLM requested). Routed by
  `tools_condition` (loop back to `agent_node` if a tool was called,
  otherwise `END`).
- **State:** `AgentState(TypedDict)` with a single field
  `messages: Annotated[list, add_messages]` — the `add_messages` reducer
  accumulates the full conversation without ever overwriting it.
- **LLM:** Ollama running `llama3.1` (8B parameters) **locally** on the
  server — no email content ever leaves the machine. `temperature=0.1`
  for classification/priority/summary (deterministic), `0.2–0.4` for
  reply generation and bulk personalisation (slightly more creative).

### 4.2 The 9 Tools

| Tool | Purpose | Depends on |
|---|---|---|
| `read_emails(query, max_results)` | Fetch emails from Gmail | Gmail API |
| `classify_email(email_id)` | Category + confidence | ClassificationChain |
| `prioritize_email(email_id, category)` | Priority + urgency score | PriorityChain |
| `summarize_email(email_id)` | 2-sentence summary + action required | SummaryChain |
| `suggest_reply(email_id, category, priority)` | Professional reply draft | SummaryChain + ReplyChain |
| `send_single_email(to, subject, body)` | Send one email | Gmail API |
| `send_bulk_email(recipients_json)` | Send identical/near-identical emails to N people | Gmail API |
| `generate_and_send_bulk_emails(recipients, topic, dry_run)` | Generate **personalised** content per recipient, optionally send | LLM + Gmail API |
| `get_urgent_emails(max_results)` | Scan inbox and return only URGENT emails | Classification + Priority chains internally |

All tools are Python functions decorated with `@tool` from
`langchain_core.tools`, registered in `ALL_TOOLS` and bound to the LLM
via `llm.bind_tools(ALL_TOOLS)`.

### 4.3 The 4 NLP Chains

Every chain follows the same pattern:
`PromptTemplate.from_template(...) | OllamaLLM | LLMOutputParser`

| Chain | Output fields | Notes |
|---|---|---|
| `ClassificationChain` | `category, confidence, reason` | Categories: `RECLAMATION`, `INFORMATION`, `SUPPORT`, `COMMERCIAL` |
| `PriorityChain` | `priority, urgency_score, reason` | Priorities: `URGENT`, `NORMAL`, `LOW`. Score 1–10 |
| `SummaryChain` | `summary, action_required, language` | Max 2 sentences. Auto-detects language (fr/en/ar) |
| `ReplyChain` | `reply, reply_subject, tone` | Replies in the **same language** as the original email |

**`LLMOutputParser`** (`agent/parser.py`) strips markdown fences and
extracts JSON even if the LLM adds surrounding text; `safe_parse()`
returns a sensible default instead of throwing if parsing fails — the
pipeline must never crash because the LLM added a stray sentence before
the JSON.

### 4.4 Conversation Memory

`ConversationMemory` (`agent/memory.py`) holds the full message history
for a session. When it exceeds `MAX_MESSAGES = 30`, the oldest messages
are summarised by the LLM into a single `SystemMessage` and replaced,
keeping the most recent 6 messages intact. This is what allows a user to
say "reply to the urgent ones" after a prior "classify my emails"
instruction without re-stating context.

### 4.5 Repository Structure (Agent)

```
ai-email-agent/
├── agent/
│   ├── agent.py            # EmailAgent — LangGraph ReAct orchestration
│   ├── bulk_generator.py   # BulkEmailGenerator — personalised bulk emails
│   ├── chains.py           # EmailChains — the 4 NLP chains
│   ├── logger.py           # AgentLogger — logs every analysis to JSON
│   ├── memory.py           # ConversationMemory
│   ├── parser.py           # LLMOutputParser
│   ├── pipeline.py         # EmailPipeline — full classify→prioritise→summarise→reply
│   ├── prompts.py          # All prompt templates (7 total)
│   └── tools.py            # The 9 @tool-decorated functions
├── auth/gmail_auth.py       # OAuth 2.0 flow, token.json persistence
├── config/settings.py       # pydantic-settings, reads .env
├── data/
│   ├── evaluate.py          # --collect / --annotate / --compute CLI
│   └── training/             # Exported evaluation JSON files
├── gmail/
│   ├── reader.py             # fetch_emails(), fetch_single_email(), MIME decoding
│   └── sender.py              # send_email(), send_bulk_emails()
├── tests/                     # 38 pytest tests across 5 files, all passing
├── demo.py                    # 5 automated demo scenarios
├── main.py                    # Interactive CLI (chat with the agent)
└── requirements.txt
```

### 4.6 Evaluation & Quality Targets

| Metric | Target | Status |
|---|---|---|
| Classification accuracy | ≥ 85% | Measured via `data/evaluate.py` |
| Priority accuracy | ≥ 80% | Measured via `data/evaluate.py` |
| Email processing time | ≤ 10 s | — |
| Unit test coverage | ≥ 70% | 38/38 tests passing |

Evaluation workflow: `--collect N` (agent analyses N real emails and
logs predictions) → `--annotate file.json` (human corrects labels
interactively in the terminal) → `--compute file.json` (prints
precision/recall/F1 per category and flags misclassifications).

---

## 5. Jury Agent (Agent 2) — External Contract

Built independently by a teammate. **Treat as a black box** — do not
assume internal implementation. The mobile app and backend only need
its **output contract**:

```json
{
  "verdict": "VALIDATED | REJECTED | PENDING",
  "confidenceScore": 0.0,
  "comment": "string explaining the verdict"
}
```

It receives the original email, Agent 1's `EmailAnalysis`, and Agent 1's
`AgentResponse`, and independently judges whether the generated reply is
appropriate before it is ever sent.

---

## 6. Mobile Application — Architecture

### 6.1 Pattern: MVVM + Clean Architecture, 3 layers

```
Presentation Layer   (Screens + ViewModels)
        ↓ depends on
Domain Layer         (Entities + UseCases + Repository INTERFACES)
        ↓ implemented by
Data Layer           (Repository IMPLEMENTATIONS + Remote/Local DataSources)
```

**Rule:** the Domain layer has zero dependencies on Presentation or
Data. Repositories are interfaces in Domain, implementations live in
Data. ViewModels only ever talk to UseCases, never directly to
Repositories or DataSources.

### 6.2 Domain Layer — Entities

```
User               { id, name, email, photoUrl, gmailAccessToken,
                      gmailRefreshToken, tokenExpiry, createdAt, isActive }

GmailCredential    { accessToken, refreshToken, tokenExpiry, scope }
                     (composition of User — doesn't exist without it)

Email              { id, gmailId, subject, sender, recipients[],
                      bodyText, receivedAt, status: EmailStatus, isRead }

EmailAnalysis      { id, category: EmailCategory, priority: PriorityLevel,
                      urgencyScore(1-10), confidenceScore, summary,
                      actionRequired, detectedLanguage, analysedAt }

AgentResponse      { id, replyBody, replySubject, tone,
                      generatedAt, sentAt, wasEdited }

JuryVerdictModel   { id, verdict: JuryVerdict, confidenceScore,
                      comment, verifiedAt }

ConversationMessage{ id, role: MessageRole, content, timestamp,
                      toolsUsed[] }

BulkRecipient      { id, name, email, role, context,
                      generatedSubject, generatedBody, sendStatus }

DashboardStat      { id, period, totalEmails, autoSent, reviewRequired,
                      urgentCount, avgSentimentScore, juryApprovalRate,
                      avgProcessingTimeSec, categoryBreakdown{},
                      topSenders[], computedAt }

AppSettings        { userId, autoProcessingEnabled, urgencyThreshold,
                      juryConfidenceThreshold, autoCategories[],
                      replyLanguage, dailySummaryEnabled,
                      darkModeEnabled, notificationsEnabled }

Notification       { id, type, title, body, emailId, isRead, receivedAt }
```

**Enums**

```
EmailCategory  = RECLAMATION | INFORMATION | SUPPORT | COMMERCIAL
PriorityLevel  = URGENT | NORMAL | LOW
EmailStatus    = PENDING | ANALYSED | AUTO_SENT | REVIEW_REQUIRED
                 | SENT_BY_USER | IGNORED
JuryVerdict    = VALIDATED | REJECTED | PENDING
MessageRole    = USER | AGENT | SYSTEM
```

### 6.3 Key Relationships

- `User 1 —— 0..*  Email` / `User 1 —— 1  AppSettings` (composition)
- `Email 1 —— 0..1 EmailAnalysis` / `Email 1 —— 0..1 AgentResponse`
  / `Email 1 —— 0..1 JuryVerdictModel`
- `EmailAnalysis` depends on `AIAgentService` (Agent 1) — dependency,
  not ownership

### 6.4 Domain Layer — UseCases (one per module)

`AuthUseCase`, `EmailUseCase`, `AnalysisUseCase`, `PromptUseCase`,
`BulkEmailUseCase`, `DashboardUseCase`, `SettingsUseCase`,
`NotificationUseCase`.

### 6.5 Domain Layer — Repository Interfaces

`IAuthRepository`, `IEmailRepository`, `IAgentRepository`,
`IDashboardRepository`, `ISettingsRepository`. Implemented in the Data
layer by classes of the same name without the `I` prefix
(`AuthRepository`, `EmailRepository`, etc.).

### 6.6 Presentation Layer — ViewModels

`AuthViewModel`, `HomeViewModel`, `ActivityViewModel`, `ReviewViewModel`,
`PromptViewModel`, `DashboardViewModel`, `BulkViewModel`,
`SettingsViewModel`. Each exposes observable state
(`isLoading`, `errorMessage`, the relevant data) and imperative methods
that call exactly one UseCase.

### 6.7 Data Layer

**Remote DataSources:** `GmailDataSource` (talks to Gmail API directly
for read/send), `AgentDataSource` (talks to the FastAPI backend, which
proxies to Agent 1 and Agent 2), `NotificationDataSource` (Firebase
Cloud Messaging).

**Local Storage:** `LocalDatabase` (SQLite — caches emails, analyses,
dashboard stats for offline access), `SecureStorage` (Keychain/Keystore
— OAuth tokens only, never in SQLite or SharedPreferences),
`PreferencesStorage` (SharedPreferences — non-sensitive app settings).

---

## 7. Email Lifecycle (State Machine)

```
RECEIVED → PENDING → ANALYSING → ANALYSED → VERIFYING → [DECISION]
                                                              │
                        ┌─────────────────────────────────────┤
                        ▼                                     ▼
                 AUTO_SENDING                          REVIEW_REQUIRED
                        │                                     │
              success ──┼── failure                  [USER_ACTION choice]
                 ▼            ▼                    ┌─────────┼─────────┐
            AUTO_SENT   REVIEW_REQUIRED             ▼         ▼         ▼
                                              SENDING_    SENDING_   IGNORED
                                              ORIGINAL    EDITED
                                                 │           │
                                                 ▼           ▼
                                              SENT_BY_USER (wasEdited=false/true)
```

The `[DECISION]` gate is exactly **the auto-send rule from Section 3**.
`REVIEW_REQUIRED` always triggers a push notification to the user.

---

## 8. Modules & Screens

The app has **10 functional modules** covering **74 individual
features**, expressed as **11 screens** (S01–S11).

| # | Screen | Module | Key elements |
|---|---|---|---|
| S01 | Login | Authentication | "Continue with Google" button (OAuth wired by team lead) |
| S02 | Onboarding | Authentication | 3-step carousel explaining auto-reply vs review, sets default `AppSettings` |
| S03 | **Home** | Accueil | KPI cards, urgent banner, recent activity, agent on/off toggle, FAB → Prompt, shortcuts to Dashboard/Bulk |
| S04 | Today's Activity | Today's Activity | List of emails the agent processed today, filter tabs (All/Auto-sent/Review/Ignored), date picker |
| S05 | Email Detail (read) | Vue détaillée | Original email + Agent 1 analysis + Jury verdict + the reply that was already sent |
| S06 | Review | Review/Urgent | List of emails in `REVIEW_REQUIRED`, sorted by urgency, timer since receipt |
| S07 | Email Detail (edit) | Review/Urgent | Editable reply pre-filled with the AI draft, 3 actions: Send as-is / Edit & send / Ignore |
| S08 | Prompt (Chat) | Interface Prompt | Free-text chat with Agent 1, quick-suggestion chips, visible reasoning steps, confirmation dialog before any send |
| S09 | Dashboard | Dashboard | KPIs, time-series bar chart, category pie chart, sentiment gauge, period filter (7/30/90d), PDF export |
| S10 | Bulk Email | Bulk Email | Add recipients with role/context, one shared topic, AI generates personalised drafts, preview & edit before send |
| S11 | Profile & Settings | Profil & Paramètres | Account info, agent thresholds (`urgencyThreshold`, `juryConfidenceThreshold`), toggles, sign out |

**Bottom Navigation Bar (always visible, 4 tabs):** Home · Today ·
Review (red badge = pending count) · Profile.
**Floating Action Button** on Home → opens Prompt.

---

## 9. Design System

**Brand colour:** Indigo `#4F46E5` (light tint `#EEF2FF`, mid `#818CF8`)

| Token | Hex | Use |
|---|---|---|
| Success | `#10B981` (light `#ECFDF5`) | Auto-sent, positive sentiment, validated |
| Danger | `#EF4444` (light `#FEF2F2`) | Urgent, rejected, errors |
| Warning | `#F59E0B` (light `#FFFBEB`) | Normal priority, pending states |
| Neutral scale | `#F9FAFB → #111827` | Backgrounds, borders, text hierarchy |

**Category pill colours:** RECLAMATION = red, SUPPORT = blue,
INFORMATION = green, COMMERCIAL = amber.
**Priority pill colours:** URGENT = solid red, NORMAL = amber tint,
LOW = green tint.

**Core reusable components:** KPI Card, Pill/Badge, generic Card,
Avatar (initials), Toggle/Switch, Buttons (primary / ghost / danger),
Bottom Nav Bar, FAB, Chat bubble (user vs agent), Bar chart, Pie chart,
Progress/sentiment bar, Tab selector.

Typography: system font stack, no custom font required
(`-apple-system, "Segoe UI", sans-serif` equivalent on each platform).

---

## 10. UML & Design Artefacts Already Produced

All diagrams below exist as PlantUML source + rendered PNG (A4-fit) and
are referenced in the internship report. Do not redesign them without a
strong reason — treat them as the spec.

| Diagram | What it defines |
|---|---|
| Package diagram | The 3-layer architecture + external systems (Google, Firebase, Backend) |
| Use case diagram (general) | 3 actors (User, Gmail API, Notification Service), 27 use cases, 9 packages |
| Class diagram — Part 1 | Domain entities (Section 6.2 above) |
| Class diagram — Part 2 | Repository interfaces + UseCases |
| Class diagram — Part 3 | ViewModels (MVVM) |
| Class diagram — Part 4 | Data layer (DataSources + Repository impls) |
| Sequence SD01 | OAuth 2.0 authentication flow |
| Sequence SD02 | **The core pipeline**: email received → Agent 1 analyses → Agent 2 verifies → auto-send or escalate |
| Sequence SD03 | User intervention in Review (validate / edit / reject) |
| Sequence SD04 | Prompt/Chat interaction, including the ReAct tool-calling loop and action confirmation |
| Sequence SD05 | Bulk email generation and sending |
| Sequence SD06 | Dashboard load, period filter, PDF export |
| Activity AD01 | Same as SD02 but as a decision-flow (the auto-send rule visualised) |
| Activity AD02 | Auth + onboarding, including token refresh branch |
| Activity AD03 | Review screen decision flow |
| Activity AD04 | Bulk email decision flow incl. partial failure/retry |
| State diagram | Full `Email` lifecycle (Section 7 above) |
| Component diagram | All 30+ software components and their dependencies, 3 layers + Backend + Google Cloud |
| Deployment diagram | Physical infrastructure (Section 11 below) |
| Navigation map | Screen-to-screen flow, bottom nav always accessible |
| Wireframes | All 11 screens, modern indigo palette (Section 9) |

---

## 11. Infrastructure & Deployment

```
┌─ User's Phone ────────────────────────┐
│  Mobile App (no LLM on-device)         │
│  SQLite (cache) · Keychain · Prefs     │
└──────────────┬─────────────────────────┘
               │ HTTPS / TLS 1.3, JWT Bearer
┌──────────────▼─────────────────────────┐
│  Backend Server (Docker Compose)        │
│  ├─ FastAPI          :8000              │
│  ├─ Agent IA 1        :8001              │
│  ├─ Agent IA 2 (Jury) :8002              │
│  ├─ Ollama (Llama 3.1):11434             │
│  ├─ PostgreSQL        :5432              │
│  └─ Redis             :6379              │
└──────────────┬─────────────────────────┘
               │
   ┌───────────┴────────────┐
   ▼                         ▼
Google Cloud            Firebase Cloud
(Gmail API v1,           Messaging
 OAuth 2.0)               (push notifications)
```

**Server sizing:** ≥16 GB RAM (Llama 3.1 8B needs ~8 GB), ≥8 CPU cores,
≥50 GB storage, Ubuntu 22.04 LTS.

**Gmail OAuth scopes required:** `gmail.readonly`, `gmail.send`,
`gmail.modify`.

---

## 12. Team & Roles

| Person | Role | Owns |
|---|---|---|
| **Fourat (Team Lead)** | Architecture, Agent 1, DevOps | Dev environment setup, Gmail OAuth integration, backend/agent architecture, code reviews |
| **Islem** | Frontend Dev — Core Flow & Dashboard | S01/S02 UI, Design System, S03 Home, S04 Today, S05/S07 Email Detail, S06 Review, S09 Dashboard |
| **Senda** | Frontend Dev — Architecture & Secondary Features | Project scaffolding, networking layer, local DB, DI, navigation shell, S11 Profile/Settings, Notifications, S08 Prompt, S10 Bulk Email, backend integration testing, error/offline handling |
| **Teammate (external)** | Agent 2 (Jury) | Independent verification service — contract only (Section 5) |

---

## 13. Development Roadmap (Mobile App)

4 sprints × 2 weeks, tracked on Trello (34 cards, labels = owner +
priority + type, checklists per card, due dates auto-computed from a
configurable project start date).

| Sprint | Weeks | Focus |
|---|---|---|
| Sprint 0 (Team Lead) | — | Dev env, Gmail OAuth, backend scaffolding — prerequisite, not on the dev board |
| Sprint 1 | 1–2 | Architecture scaffolding, networking, local DB, DI, navigation shell, Design System, Login/Onboarding UI, Profile screen |
| Sprint 2 | 3–4 | Email domain layer + repository, Notifications (FCM), Home screen, Today's Activity, Email Detail (read-only) |
| Sprint 3 | 5–6 | Review screen + edit mode, Prompt/Chat screen + wiring, Bulk Email screen + wiring |
| Sprint 4 | 7–8 | Dashboard screen + wiring, full backend integration testing, global error/loading states, offline handling, cross-device QA, polish, demo prep |

Automation for the Trello board lives in `generate_config.py` (builds
the JSON) and `trello_setup.py` (pushes it to the Trello API via
`.env`-supplied `TRELLO_API_KEY` / `TRELLO_TOKEN`).

---

## 14. Tech Stack Reference

| Layer | Technology |
|---|---|
| AI Agent | Python 3.11, LangChain 0.2.16, LangGraph 0.2.14 |
| LLM | Ollama, Llama 3.1 (8B), local inference, `temperature=0.1` |
| Gmail integration | Gmail API v1, google-auth-oauthlib, OAuth 2.0 |
| Backend API | FastAPI, PostgreSQL, Redis |
| Mobile app | Flutter or React Native (final pick pending) — MVVM + Clean Architecture regardless |
| Local mobile storage | SQLite (cache), Keychain/Keystore (tokens), SharedPreferences (settings) |
| Push notifications | Firebase Cloud Messaging |
| Containerisation | Docker + Docker Compose |
| Testing (agent) | Pytest — 38 tests, 100% passing |
| Diagrams | PlantUML |
| Team board | Trello (API-provisioned) |

---

## 15. Conventions & Non-Negotiables

- **Never** put OAuth tokens anywhere but `SecureStorage` — not SQLite,
  not SharedPreferences, not logs.
- **Never** bypass the auto-send rule (Section 3) in any code path that
  sends an email without prior explicit user confirmation.
- **Never** assume Agent 2's internals — only consume its documented
  JSON contract (Section 5).
- ViewModels talk to UseCases only, never directly to Repositories or
  DataSources.
- Every screen that shows AI-generated content must show it can be
  edited before it's sent, except in the fully automated (auto-send)
  path, which by definition has no UI at all.
- All emails not classified `URGENT` and not auto-sent must still end
  up either in `REVIEW_REQUIRED` or `IGNORED` — no email should be
  silently dropped.
- Reply language must match the original email's detected language
  (`SummaryChain.language` / `AppSettings.replyLanguage` as override).

---

## 16. Glossary

| Term | Meaning |
|---|---|
| Agent 1 | The email agent (built, this repo) — classifies, prioritises, drafts replies |
| Agent 2 / Jury | Independent verification agent (external, teammate's repo) |
| ReAct | Reasoning + Acting — the agent's reasoning loop pattern |
| Auto-send rule | The decision logic in Section 3 governing automatic vs manual sending |
| Review | The screen/state where a human must approve, edit, or reject a draft |
| Bulk Email | Sending distinct, AI-personalised emails to multiple recipients from one topic |
| Dry run | Generating bulk emails without actually sending them (preview mode) |
