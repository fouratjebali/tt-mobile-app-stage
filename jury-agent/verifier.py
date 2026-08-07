from schemas import JuryRequest, JuryResponse, Verdict
from rules import evaluate_rules


class JuryVerifier:
    def verify(self, request: JuryRequest) -> JuryResponse:
        result = evaluate_rules(
            email=request.email,
            analysis=request.analysis,
            agent_response=request.agent_response,
        )
        verdict = self._verdict_for(result.score, result.risk_flags)
        return JuryResponse(
            verdict=verdict,
            confidenceScore=round(result.score, 2),
            comment=self._comment(verdict, result.reasons),
            reasons=result.reasons,
            risk_flags=result.risk_flags,
        )

    def _verdict_for(self, score: float, risk_flags: list[str]) -> Verdict:
        if "empty_response" in risk_flags or "risky_language" in risk_flags:
            return "REJECTED"
        if score >= 0.85:
            return "VALIDATED"
        if score >= 0.60:
            return "PENDING"
        return "REJECTED"

    def _comment(self, verdict: Verdict, reasons: list[str]) -> str:
        intro = {
            "VALIDATED": "The response is safe to proceed.",
            "PENDING": "The response should be reviewed by a human.",
            "REJECTED": "The response should not be sent.",
        }[verdict]
        return f"{intro} {' '.join(reasons)}"
