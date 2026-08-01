from fastapi import FastAPI

from schemas import JuryRequest, JuryResponse
from verifier import JuryVerifier


app = FastAPI(
    title="TT Mail Assistant Jury Agent",
    description="Rule-based verifier for Agent 1 email analyses and draft replies.",
)
verifier = JuryVerifier()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "jury-agent"}


@app.post("/verify", response_model=JuryResponse)
def verify(request: JuryRequest) -> JuryResponse:
    return verifier.verify(request)
