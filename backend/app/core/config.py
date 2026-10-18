import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    DEFAULT_SEMINAR_FEE: float = float(os.getenv("DEFAULT_SEMINAR_FEE", "150.00"))
    ENTRANCE_PIN: str = os.getenv("ENTRANCE_PIN", "1111")
    FINANCE_PIN: str = os.getenv("FINANCE_PIN", "2222")
    ADMIN_PIN: str = os.getenv("ADMIN_PIN", "9999")


settings = Settings()