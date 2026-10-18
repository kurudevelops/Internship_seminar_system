from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from app.core.database import supabase
from app.core.realtime import realtime_manager
from app.features.entrance.schemas import (
    EntranceAttendanceRequest,
    EntranceWalkInRequest,
)

router = APIRouter(prefix="/api/entrance", tags=["Entrance Desk"])


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("/lookup")
def entrance_lookup(
    q: Optional[str] = Query(None, description="Search by Student ID, Name, Email, or Section"),
):
    res = (
        supabase.table("seminar_attendees")
        .select("*")
        .order("created_at", desc=True)
        .execute()
    )
    rows = res.data or []

    if q and q.strip():
        needle = q.strip().lower()
        rows = [
            r for r in rows
            if needle in str(r.get("student_id", "")).lower()
            or needle in str(r.get("full_name", "")).lower()
            or needle in str(r.get("email", "")).lower()
            or needle in str(r.get("program_section", "")).lower()
        ]

    return {"count": len(rows), "data": rows}


@router.get("/verify-online")
def verify_online_registration(
    student_id: Optional[str] = Query(None),
    email: Optional[str] = Query(None),
):
    sid = (student_id or "").strip()
    em = (email or "").strip().lower()

    if not sid and not em:
        raise HTTPException(
            status_code=400,
            detail="Provide Student ID or Email to check registration.",
        )

    filters = []
    if sid:
        filters.append(f"student_id.ilike.{sid}")
    if em:
        filters.append(f"email.ilike.{em}")

    res = (
        supabase.table("seminar_attendees")
        .select("*")
        .or_(",".join(filters))
        .execute()
    )

    if not res.data:
        return {
            "registered": False,
            "message": "Student is NOT yet registered.",
            "attendee": None,
        }

    record = res.data[0]
    return {
        "registered": True,
        "message": f"Registered ({record['registration_type']})",
        "attendee": record,
    }


@router.post("/walk-in")
async def create_walk_in_at_entrance(payload: EntranceWalkInRequest):
    sid = payload.student_id.strip()
    name = payload.full_name.strip()
    email = payload.email.strip().lower()
    section = payload.program_section.strip()

    if "@" not in email:
        raise HTTPException(status_code=400, detail="Valid email address is required.")

    dup = (
        supabase.table("seminar_attendees")
        .select("*")
        .or_(f"student_id.ilike.{sid},email.ilike.{email}")
        .execute()
    )
    if dup.data:
        existing = dup.data[0]
        raise HTTPException(
            status_code=409,
            detail=(
                f"Duplicate: {existing['full_name']} ({existing['student_id']}) "
                f"is already registered as {existing['registration_type']}."
            ),
        )

    ts = now_iso()
    method = payload.payment_method.upper() if payload.mark_paid_now else "NONE"
    if method not in ("NONE", "CASH", "GCASH"):
        method = "CASH"

    new_row = {
        "student_id": sid,
        "full_name": name,
        "email": email,
        "program_section": section,
        "registration_type": "WALK_IN",
        "is_present": payload.mark_present_now,
        "time_in": ts if payload.mark_present_now else None,
        "is_paid": payload.mark_paid_now,
        "amount_paid": payload.amount_paid if payload.mark_paid_now else 0.0,
        "payment_method": method,
        "paid_at": ts if payload.mark_paid_now else None,
    }

    ins = supabase.table("seminar_attendees").insert(new_row).execute()
    if not ins.data:
        raise HTTPException(status_code=500, detail="Could not create walk-in record.")

    # Broadcast instant update to all other Entrance, Admin, and Finance screens
    await realtime_manager.broadcast_update("WALK_IN_CREATED")

    return {
        "message": f"Walk-in registered: {name}",
        "data": ins.data[0],
    }


@router.patch("/check-in/{student_id}")
async def entrance_set_attendance(student_id: str, payload: EntranceAttendanceRequest):
    sid = student_id.strip()
    res = supabase.table("seminar_attendees").select("*").eq("student_id", sid).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail=f"Student ID {sid} not found.")

    update_payload = {
        "is_present": payload.is_present,
        "time_in": now_iso() if payload.is_present else None,
    }

    upd = (
        supabase.table("seminar_attendees")
        .update(update_payload)
        .eq("student_id", sid)
        .execute()
    )

    # Broadcast instant update to all other Entrance, Admin, and Finance screens
    await realtime_manager.broadcast_update("ATTENDANCE_UPDATED")

    status_label = "PRESENT" if payload.is_present else "ABSENT"
    return {
        "message": f"Marked {res.data[0]['full_name']} as {status_label}.",
        "data": upd.data[0] if upd.data else None,
    }