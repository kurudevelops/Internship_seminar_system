from pydantic import BaseModel, Field


class AdminCreateAttendeeRequest(BaseModel):
    student_id: str = Field(..., min_length=1)
    full_name: str = Field(..., min_length=2)
    email: str = Field(..., min_length=3)
    program_section: str = Field(..., min_length=2)
    registration_type: str = Field("PRE_REGISTERED", pattern="^(PRE_REGISTERED|WALK_IN)$")
    is_present: bool = False
    is_paid: bool = False
    amount_paid: float = 0.0
    payment_method: str = "NONE"


class AdminUpdateAttendeeRequest(BaseModel):
    student_id: str = Field(..., min_length=1)
    full_name: str = Field(..., min_length=2)
    email: str = Field(..., min_length=3)
    program_section: str = Field(..., min_length=2)
    registration_type: str = Field(..., pattern="^(PRE_REGISTERED|WALK_IN)$")
    is_present: bool
    is_paid: bool
    amount_paid: float
    payment_method: str


class AdminTogglePresenceRequest(BaseModel):
    is_present: bool


class AdminCsvImportRequest(BaseModel):
    csv_content: str