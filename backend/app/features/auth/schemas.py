from pydantic import BaseModel


class PinVerifyRequest(BaseModel):
    role: str  # ENTRANCE, FINANCE, ADMIN
    pin: str