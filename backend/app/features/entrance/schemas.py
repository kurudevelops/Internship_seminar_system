from pydantic import BaseModel, Field


class EntranceWalkInRequest(BaseModel):
    student_id: str = Field(..., min_length=1)
    full_name: str = Field(..., min_length=2)
    email: str = Field(..., min_length=3)
    program_section: str = Field(..., min_length=2)
    mark_present_now: bool = True
    mark_paid_now: bool = False
    amount_paid: float = 0.0
    payment_method: str = "NONE"


class EntranceAttendanceRequest(BaseModel):
    is_present: bool