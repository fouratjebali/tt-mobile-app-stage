from pydantic import Field
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "TT Mail Assistant Backend"
    APP_VERSION: str = "0.1.0"
    API_V1_PREFIX: str = "/api/v1"

    POSTGRES_USER: str = "user"
    POSTGRES_PASSWORD: str = "password"
    POSTGRES_DB: str = "tt_mail_db"
    DATABASE_URL: str = "postgresql://user:password@postgres:5432/tt_mail_db"

    REDIS_URL: str = "redis://redis:6379"
    AGENT1_URL: str = Field(default="http://agent1:8001")
    AGENT2_URL: str = Field(default="http://agent2:8002")
    SENTIMENT_AGENT_URL: str = Field(default="http://sentiment-agent:8003")
    GOOGLE_OAUTH_CLIENT_ID: str = ""
    GOOGLE_OAUTH_SERVER_CLIENT_ID: str = ""

    HTTP_TIMEOUT_SECONDS: float = 120.0

    @model_validator(mode="after")
    def normalize_database_url(self) -> "Settings":
        if self.DATABASE_URL.startswith("postgresql://"):
            self.DATABASE_URL = self.DATABASE_URL.replace(
                "postgresql://", "postgresql+psycopg://", 1
            )
        return self

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
