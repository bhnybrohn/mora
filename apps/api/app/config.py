from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://localhost:5432/mora"
    redis_url: str = "redis://localhost:6379/0"
    secret_key: str = "change-me-in-production"
    cors_origins: list[str] = ["*"]

    # Storage
    storage_backend: str = "local"  # "local" | "r2"
    storage_local_dir: str = "./uploads"
    storage_public_base_url: str = "http://localhost:8000"
    r2_endpoint: str = ""
    r2_access_key: str = ""
    r2_secret_key: str = ""
    r2_bucket_photos: str = "mora-photos-prod"
    r2_bucket_previews: str = "mora-previews-prod"

    # Auth
    otp_provider_api_key: str = ""
    jwt_expire_minutes: int = 60 * 24  # 24 hours

    # Payment
    paystack_secret_key: str = ""
    flutterwave_secret_key: str = ""
    stripe_secret_key: str = ""

    # Notifications
    africastalking_api_key: str = ""
    africastalking_username: str = ""
    vapid_public_key: str = ""
    vapid_private_key: str = ""
    vapid_claim_email: str = "hello@mora.app"

    model_config = {"env_file": ".env", "extra": "allow"}


settings = Settings()
