# ----------------------------------------------------------
# PROMPT 1 : CLASSIFICATION (version améliorée Day 5)
# ----------------------------------------------------------
CLASSIFICATION_PROMPT = """
You are an expert email classifier for a professional telecommunications company.
Classify the email below into exactly ONE category.

Category definitions (read carefully) :
- RECLAMATION  : complaint, dissatisfaction, problem report, service failure,
                 bad experience, refund request, angry tone, "not working",
                 "disappointed", "unacceptable"
- INFORMATION  : newsletter, announcement, update, notification, FYI,
                 no response needed, automated email, subscription, news
- SUPPORT      : request for help, technical question, how-to question,
                 needs human response, account issue, configuration problem
- COMMERCIAL   : invoice, order confirmation, payment, promotion, offer,
                 discount, pricing, contract, purchase, subscription renewal

Decision rules :
1. If the email has an angry or frustrated tone → RECLAMATION
2. If it is automated / no-reply → INFORMATION
3. If it asks a question expecting an answer → SUPPORT
4. If it involves money, products or services → COMMERCIAL
5. When in doubt between SUPPORT and RECLAMATION : if there is frustration → RECLAMATION

Email :
Subject : {subject}
From    : {sender}
Body    :
{body}

Respond ONLY with valid JSON, no markdown, no extra text :
{{
  "category"   : "RECLAMATION | INFORMATION | SUPPORT | COMMERCIAL",
  "confidence" : 0.0,
  "reason"     : "one short sentence explaining the classification"
}}
"""

# ----------------------------------------------------------
# PROMPT 2 : PRIORITÉ (version améliorée Day 5)
# ----------------------------------------------------------
PRIORITY_PROMPT = """
You are an expert at evaluating email urgency for a telecommunications professional.
Determine the priority level of the email below.

Priority levels :
- URGENT : requires response within 2 hours
           Signals : deadline today, service outage, angry VIP client,
           words like "urgent", "ASAP", "immediately", "critical",
           "emergency", "deadline", "not working right now", escalation
- NORMAL : requires response within 24 hours
           Signals : standard question, colleague request, meeting invitation,
           routine follow-up
- LOW    : can wait more than 24 hours
           Signals : newsletter, FYI, automated notification,
           no action required, future events

Context from classification :
Category : {category}
(RECLAMATION emails should lean toward URGENT or NORMAL,
 INFORMATION emails should lean toward LOW)

Email :
Subject : {subject}
From    : {sender}
Body    :
{body}

Urgency scoring guide :
9-10 : service down, angry VIP, deadline in hours
7-8  : important request, complaint, same-day meeting
5-6  : normal work request, routine question
3-4  : low priority question, future planning
1-2  : newsletter, automated email, no action needed

Respond ONLY with valid JSON, no markdown, no extra text :
{{
  "priority"      : "URGENT | NORMAL | LOW",
  "urgency_score" : 0,
  "reason"        : "one short sentence explaining the priority"
}}
"""

# ----------------------------------------------------------
# PROMPT 6 : GÉNÉRATION BULK EMAIL PERSONNALISÉ
# ----------------------------------------------------------
BULK_PERSONALIZED_PROMPT = """
You are an expert professional email writer.
You must write a PERSONALIZED email for ONE specific recipient.

Recipient details:
- Name    : {name}
- Email   : {email}
- Role    : {role}
- Context : {context}

General topic / purpose of the email:
{topic}

Additional instructions:
{instructions}

STRICT RULES:
- Write ONLY for THIS recipient, using their specific context.
- Personalize: mention their name, role, and specific context.
- Do NOT write a generic email that could fit anyone.
- Language: write in French unless specified otherwise.
- Length: 4-6 sentences, professional tone.
- Respond ONLY with valid JSON, no markdown, no extra text.

JSON response:
{{
  "subject": "personalized subject line",
  "body": "complete personalized email body with greeting and signature",
  "personalization_note": "what was personalized for this recipient"
}}
"""

# ----------------------------------------------------------
# PROMPT 7 : RÉSUMÉ DE CONVERSATION
# ----------------------------------------------------------
CONVERSATION_SUMMARY_PROMPT = """
You are summarizing a conversation between a user and an AI email assistant.

Conversation history:
{history}

Create a concise summary that captures:
1. What emails were read/analyzed
2. What actions were taken (sent, classified, etc.)
3. Any important email IDs or recipients mentioned
4. Current context/state

Respond ONLY with valid JSON:
{{
  "summary": "2-3 sentence summary",
  "emails_processed": ["list of email subjects or IDs"],
  "actions_taken": ["list of actions"],
  "pending_actions": ["list of things not yet done"]
}}
"""


try:
    from langchain_core.prompts import PromptTemplate
except ImportError:
    PromptTemplate = None


if PromptTemplate is not None:
    email_analysis_prompt = PromptTemplate.from_template(
        """
You are a multilingual email triage assistant for English and French emails.
Analyze the email and return only valid JSON.

Rules:
- Detect French accurately, including accents and common business terms.
- Do not default French professional emails to LOW unless they are clearly automated and informational.
- Recruitment, internship, job offers, interviews, applications, invoices, offers and contracts are COMMERCIAL.
- Direct invitations, meetings, confirmations, questions and requests for help are SUPPORT.
- Complaints, dissatisfaction, incidents, outages and refund requests are RECLAMATION.
- Newsletters, no-reply updates and FYI messages with no user action are INFORMATION.
- Use URGENT for same-day deadlines, outages, angry complaints, blocked service, escalation or explicit urgency.
- Use NORMAL for direct invitations, opportunities, support questions and replies expected within 24 hours.
- Use LOW only for automated/no-action information.
- Write the suggested reply in the same language as the email.
- Make the reply specific to the email context; avoid generic "I will get back if needed" replies when action is requested.

Email:
Subject: {subject}
From: {sender}
Category hint, if any: {category}
Body:
{body}

JSON schema:
{{
  "category": "RECLAMATION | INFORMATION | SUPPORT | COMMERCIAL",
  "confidence": 0.0,
  "priority": "URGENT | NORMAL | LOW",
  "urgency_score": 0,
  "summary": "one concise summary sentence",
  "action_required": "specific action or no immediate action required",
  "language": "fr | en | unknown",
  "suggested_reply": "complete proposed reply",
  "reply_subject": "reply subject",
  "tone": "professional | helpful | courteous | neutral",
  "reason": "short reason"
}}
"""
    )
else:
    email_analysis_prompt = None
