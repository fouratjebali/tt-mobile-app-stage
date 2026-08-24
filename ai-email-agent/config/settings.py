from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "llama3.1"
    OLLAMA_TIMEOUT_SECONDS: float = 180.0
    OLLAMA_NUM_PREDICT: int = 256
    OLLAMA_NUM_GPU: int = 0
    MAX_EMAILS: int = 10
    LOG_LEVEL: str = "INFO"
    client_id: str | None = None
    client_secret: str | None = None
    MICROSOFT_CLIENT_ID: str | None = None
    MICROSOFT_CLIENT_SECRET: str | None = None
    MICROSOFT_TENANT_ID: str = "common"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
