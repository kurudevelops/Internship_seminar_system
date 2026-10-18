from pydantic import BaseModel, Field


class FinancePaymentUpdateRequest(BaseModel):
    is_paid: bool
    amount_paid: float = Field(ge=0.0)
    payment_method: str = Field("CASH", pattern="^(NONE|CASH|GCASH)$")