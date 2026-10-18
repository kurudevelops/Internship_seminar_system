from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from app.core.config import settings
from app.core.database import supabase
from app.features.finance.schemas import FinancePaymentUpdateRequest

router = APIRouter(prefix="/api/finance", tags=["Finance"])


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def calculate_finance_summary(rows: List[dict]) -> dict:
    total_attendees = len(rows)
    paid_rows = [r for r in rows if r.get("is_paid") is True]
    unpaid_rows = [r for r in rows if not r.get("is_paid")]

    total_paid_count = len(paid_rows)
    total_unpaid_count = len(unpaid_rows)

    total_earnings = sum(float(r.get("amount_paid") or 0.0) for r in paid_rows)

    pre_reg_earnings = sum(
        float(r.get("amount_paid") or 0.0)
        for r in paid_rows
        if r.get("registration_type") == "PRE_REGISTERED"
    )
    walk_in_earnings = sum(
        float(r.get("amount_paid") or 0.0)
        for r in paid_rows
        if r.get("registration_type") == "WALK_IN"
    )
    cash_earnings = sum(
        float(r.get("amount_paid") or 0.0)
        for r in paid_rows
        if r.get("payment_method") == "CASH"
    )
    gcash_earnings = sum(
        float(r.get("amount_paid") or 0.0)
        for r in paid_rows
        if r.get("payment_method") == "GCASH"
    )

    estimated_receivables = total_unpaid_count * settings.DEFAULT_SEMINAR_FEE

    return {
        "default_seminar_fee": settings.DEFAULT_SEMINAR_FEE,
        "total_attendees": total_attendees,
        "total_paid_count": total_paid_count,
        "total_unpaid_count": total_unpaid_count,
        "total_earnings": round(total_earnings, 2),
        "pre_registered_earnings": round(pre_reg_earnings, 2),
        "walk_in_earnings": round(walk_in_earnings, 2),
        "cash_earnings": round(cash_earnings, 2),
        "gcash_earnings": round(gcash_earnings, 2),
        "estimated_uncollected": round(estimated_receivables, 2),
    }


@router.get("/ledger")
def get_finance_ledger(
    q: Optional[str] = Query(None),
    payment_status: Optional[str] = Query(None, description="ALL, PAID, UNPAID"),
    registration_type: Optional[str] = Query(None, description="ALL, PRE_REGISTERED, WALK_IN"),
):
    res = (
        supabase.table("seminar_attendees")
        .select("*")
        .order("created_at", desc=True)
        .execute()
    )
    all_rows = res.data or []
    summary = calculate_finance_summary(all_rows)

    filtered = all_rows
    if payment_status == "PAID":
        filtered = [r for r in filtered if r.get("is_paid") is True]
    elif payment_status == "UNPAID":
        filtered = [r for r in filtered if not r.get("is_paid")]

    if registration_type and registration_type != "ALL":
        filtered = [r for r in filtered if r.get("registration_type") == registration_type]

    if q and q.strip():
        needle = q.strip().lower()
        filtered = [
            r for r in filtered
            if needle in str(r.get("student_id", "")).lower()
            or needle in str(r.get("full_name", "")).lower()
            or needle in str(r.get("email", "")).lower()
            or needle in str(r.get("program_section", "")).lower()
        ]

    return {
        "summary": summary,
        "count": len(filtered),
        "data": filtered,
    }


@router.patch("/payment/{attendee_id}")
def update_payment_status(attendee_id: str, payload: FinancePaymentUpdateRequest):
    res = supabase.table("seminar_attendees").select("*").eq("id", attendee_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Attendee record not found.")

    attendee = res.data[0]
    method = payload.payment_method.upper() if payload.is_paid else "NONE"
    amount = payload.amount_paid if payload.is_paid else 0.0

    update_data = {
        "is_paid": payload.is_paid,
        "amount_paid": amount,
        "payment_method": method,
        "paid_at": now_iso() if payload.is_paid else None,
    }

    upd = (
        supabase.table("seminar_attendees")
        .update(update_data)
        .eq("id", attendee_id)
        .execute()
    )

    label = f"PAID (PHP {amount:.2f} via {method})" if payload.is_paid else "UNPAID"
    return {
        "message": f"Updated {attendee['full_name']} payment status to {label}.",
        "data": upd.data[0] if upd.data else None,
    }