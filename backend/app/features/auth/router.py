from fastapi import APIRouter, HTTPException
from app.core.config import settings
from app.features.auth.schemas import PinVerifyRequest

router = APIRouter(prefix="/api/auth", tags=["Auth"])


@router.post("/verify-pin")
def verify_role_pin(payload: PinVerifyRequest):
    role = payload.role.strip().upper()
    pin = payload.pin.strip()

    pin_map = {
        "ENTRANCE": settings.ENTRANCE_PIN,
        "FINANCE": settings.FINANCE_PIN,
        "ADMIN": settings.ADMIN_PIN,
    }

    if role not in pin_map:
        raise HTTPException(status_code=400, detail="Invalid role specified.")

    # Admin PIN can unlock any workspace
    if pin == settings.ADMIN_PIN or pin == pin_map[role]:
        return {
            "authenticated": True,
            "role": role,
            "default_seminar_fee": settings.DEFAULT_SEMINAR_FEE,
        }

    raise HTTPException(status_code=401, detail="Invalid access PIN for this workspace.")