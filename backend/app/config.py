from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./caresync.db"
    upload_dir: Path = Path("./storage/uploads")
    max_upload_bytes: int = 10 * 1024 * 1024
    reminder_grace_minutes: int = 15
    nominee_escalation_minutes: int = 30
    hospital_missed_days_threshold: int = 3
    cloudinary_url: str | None = None
    whisper_model_size: str = "base"
    whisper_device: str = "cpu"
    whisper_compute_type: str = "int8"
    max_audio_upload_bytes: int = 25 * 1024 * 1024
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-2.0-flash"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
