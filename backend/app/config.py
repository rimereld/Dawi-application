import os
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, loaded from environment variables / .env file."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    anthropic_api_key: str = "AIzaSyAFcY1I3NzWxV-K0JcHkYLE3-Jk95fbgBU"
    anthropic_model: str = "gemini-3.5-flash"

    database_url: str = "sqlite:///./rx_scanner.db"

    tesseract_cmd: str = ""
    upload_dir: str = "app/uploads"

    allowed_origins: str = "*"

    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 14  # 2 weeks

    @property
    def allowed_origins_list(self) -> list[str]:
        if self.allowed_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    os.makedirs(settings.upload_dir, exist_ok=True)
    return settings
