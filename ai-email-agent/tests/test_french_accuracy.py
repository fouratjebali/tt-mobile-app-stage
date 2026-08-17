from agent.chains import EmailChains


def test_french_job_offer_is_normal_commercial_with_specific_reply():
    chains = EmailChains()
    subject = "Fourat, répondez à l'offre d'emploi de Stage - Développeur Full Stack H/F"
    sender = "LinkedIn <jobs-noreply@linkedin.com>"
    body = (
        "Cet e-mail est destiné à Fourat Jebali. "
        "Répondez à l'offre d'emploi de Stage - Développeur Full Stack."
    )

    classification = chains._rule_based_classify(subject, sender, body)
    priority = chains._rule_based_priority(subject, sender, body, classification.category)
    summary = chains._rule_based_summary(subject, sender, body)
    reply = chains._rule_based_reply(
        subject,
        sender,
        body,
        classification.category,
        priority.priority,
        summary.summary,
    )

    assert classification.category == "COMMERCIAL"
    assert priority.priority == "NORMAL"
    assert summary.language == "fr"
    assert "opportunité" in reply.reply


def test_french_complaint_with_service_down_is_urgent():
    chains = EmailChains()
    subject = "Réclamation urgente"
    sender = "client@example.com"
    body = (
        "Bonjour, ma connexion ne fonctionne pas depuis ce matin. "
        "Merci de résoudre le problème aujourd'hui."
    )

    classification = chains._rule_based_classify(subject, sender, body)
    priority = chains._rule_based_priority(subject, sender, body, classification.category)
    reply = chains._rule_based_reply(
        subject,
        sender,
        body,
        classification.category,
        priority.priority,
        "La connexion ne fonctionne pas.",
    )

    assert classification.category == "RECLAMATION"
    assert priority.priority == "URGENT"
    assert priority.urgency_score >= 8
    assert "priorité" in reply.reply


def test_english_direct_invitation_is_not_low_and_reply_is_english():
    chains = EmailChains()
    subject = "invitation to summercamp 2027"
    sender = "director@example.com"
    body = (
        "Hello Fourat, I am the director of summercamp event 2027 in Berlin "
        "and I am inviting you to be there if you want."
    )

    classification = chains._rule_based_classify(subject, sender, body)
    priority = chains._rule_based_priority(subject, sender, body, classification.category)
    reply = chains._rule_based_reply(
        subject,
        sender,
        body,
        classification.category,
        priority.priority,
        body,
    )

    assert classification.category == "SUPPORT"
    assert priority.priority == "NORMAL"
    assert reply.reply.startswith("Hello,")
    assert "invitation" in reply.reply.lower()


def test_automated_linkedin_reaction_stays_low_information():
    chains = EmailChains()
    subject = "Slama Med Amine a réagi à ce post : The 2027 Mitacs Globalink"
    sender = "LinkedIn <updates-noreply@linkedin.com>"
    body = "Slama Med Amine aime ceci. Elyes Manai, Ph.D. J'AIME ÉLOGE EMPATHIE 135, 4 Commentaires."

    classification = chains._rule_based_classify(subject, sender, body)
    priority = chains._rule_based_priority(subject, sender, body, classification.category)

    assert classification.category == "INFORMATION"
    assert priority.priority == "LOW"
