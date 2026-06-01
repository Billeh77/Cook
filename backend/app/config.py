from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str = ""
    replicate_api_token: str = ""
    database_url: str = "postgresql://postgres:postgres@localhost:5432/grocerylist"
    environment: str = "development"
    log_level: str = "INFO"
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    model_config = {"env_file": ".env", "extra": "ignore", "env_ignore_empty": True}


settings = Settings()
