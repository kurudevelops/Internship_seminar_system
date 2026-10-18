import csv
import io
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from app.core.database import supabase
from app.features.admin.schemas import (
    AdminCreateAttendeeRequest,
    AdminCsvImportRequest,
    AdminTogglePresenceRequest,
    AdminUpdateAttendeeRequest,
)

router = APIRouter(prefix="/api/admin", tags=["Admin & Execom"])


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def calculate_admin_summary(rows: List[dict]) -> dict:
    total_registered = len(rows)
    pre_reg_rows = [r for r in rows if r.get("registration_type") == "PRE_REGISTERED"]
    walk_in_rows = [r for r in rows if r.get("registration_type") == "WALK_IN"]

    total_pre_registered = len(pre_reg_rows)
    total_walk_in = len(walk_in_rows)

    pre_registered_present = sum(1 for r in pre_reg_rows if r.get("is_present") is True)
    pre_registered_absent = sum(1 for r in pre_reg_rows if not r.get("is_present"))

    walk_in_present = sum(1 for r in walk_in_rows if r.get("is_present") is True)
    walk_in_absent = sum(1 for r in walk_in_rows if not r.get("is_present"))

    total_present = pre_registered_present + walk_in_present
    total_absent = pre_registered_absent + walk_in_absent

    return {
        "total_registered": total_registered,
        "total_pre_registered": total_pre_registered,
        "total_walk_in": total_walk_in,
        "total_present": total_present,
        "total_absent": total_absent,
        "pre_registered_present": pre_registered_present,
        "pre_registered_absent": pre_registered_absent,
        "walk_in_present": walk_in_present,
        "walk_in_absent": walk_in_absent,
    }


@router.get("/dashboard")
def get_admin_dashboard(
    q: Optional[str] = Query(None),
    registration_type: Optional[str] = Query(None, description="ALL, PRE_REGISTERED, WALK_IN"),
    presence: Optional[str] = Query(None, description="ALL, PRESENT, ABSENT"),
):
    res = (
        supabase.table("seminar_attendees")
        .select("*")
        .order("created_at", desc=True)
        .execute()
    )
    all_rows = res.data or []
    summary = calculate_admin_summary(all_rows)

    filtered = all_rows
    if registration_type and registration_type != "ALL":
        filtered = [r for r in filtered if r.get("registration_type") == registration_type]

    if presence == "PRESENT":
        filtered = [r for r in filtered if r.get("is_present") is True]
    elif presence == "ABSENT":
        filtered = [r for r in filtered if not r.get("is_present")]

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


@router.post("/attendees")
def admin_create_attendee(payload: AdminCreateAttendeeRequest):
    sid = payload.student_id.strip()
    email = payload.email.strip().lower()

    dup = (
        supabase.table("seminar_attendees")
        .select("id, student_id, full_name")
        .or_(f"student_id.ilike.{sid},email.ilike.{email}")
        .execute()
    )
    if dup.data:
        raise HTTPException(
            status_code=409,
            detail=f"Record with ID '{sid}' or email '{email}' already exists.",
        )

    ts = now_iso()
    method = payload.payment_method.upper() if payload.is_paid else "NONE"
    if method not in ("NONE", "CASH", "GCASH"):
        method = "CASH"

    new_row = {
        "student_id": sid,
        "full_name": payload.full_name.strip(),
        "email": email,
        "program_section": payload.program_section.strip(),
        "registration_type": payload.registration_type,
        "is_present": payload.is_present,
        "time_in": ts if payload.is_present else None,
        "is_paid": payload.is_paid,
        "amount_paid": payload.amount_paid if payload.is_paid else 0.0,
        "payment_method": method,
        "paid_at": ts if payload.is_paid else None,
    }

    ins = supabase.table("seminar_attendees").insert(new_row).execute()
    return {
        "message": f"Created record for {payload.full_name}.",
        "data": ins.data[0] if ins.data else None,
    }


@router.put("/attendees/{attendee_id}")
def admin_update_attendee(attendee_id: str, payload: AdminUpdateAttendeeRequest):
    existing_res = (
        supabase.table("seminar_attendees")
        .select("*")
        .eq("id", attendee_id)
        .execute()
    )
    if not existing_res.data:
        raise HTTPException(status_code=404, detail="Attendee record not found.")

    current = existing_res.data[0]
    ts = now_iso()

    time_in = current.get("time_in")
    if payload.is_present and not time_in:
        time_in = ts
    elif not payload.is_present:
        time_in = None

    paid_at = current.get("paid_at")
    method = payload.payment_method.upper() if payload.is_paid else "NONE"
    if method not in ("NONE", "CASH", "GCASH"):
        method = "CASH"

    if payload.is_paid and not paid_at:
        paid_at = ts
    elif not payload.is_paid:
        paid_at = None

    update_data = {
        "student_id": payload.student_id.strip(),
        "full_name": payload.full_name.strip(),
        "email": payload.email.strip().lower(),
        "program_section": payload.program_section.strip(),
        "registration_type": payload.registration_type,
        "is_present": payload.is_present,
        "time_in": time_in,
        "is_paid": payload.is_paid,
        "amount_paid": payload.amount_paid if payload.is_paid else 0.0,
        "payment_method": method,
        "paid_at": paid_at,
    }

    upd = (
        supabase.table("seminar_attendees")
        .update(update_data)
        .eq("id", attendee_id)
        .execute()
    )
    return {
        "message": f"Updated {payload.full_name}.",
        "data": upd.data[0] if upd.data else None,
    }


@router.patch("/attendees/{attendee_id}/presence")
def admin_toggle_presence(attendee_id: str, payload: AdminTogglePresenceRequest):
    res = supabase.table("seminar_attendees").select("*").eq("id", attendee_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Attendee not found.")

    update_data = {
        "is_present": payload.is_present,
        "time_in": now_iso() if payload.is_present else None,
    }
    upd = (
        supabase.table("seminar_attendees")
        .update(update_data)
        .eq("id", attendee_id)
        .execute()
    )
    state_str = "Present" if payload.is_present else "Absent"
    return {
        "message": f"Marked {res.data[0]['full_name']} as {state_str}.",
        "data": upd.data[0] if upd.data else None,
    }


@router.delete("/attendees/{attendee_id}")
def admin_delete_attendee(attendee_id: str):
    res = supabase.table("seminar_attendees").delete().eq("id", attendee_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Attendee not found.")
    return {"message": f"Removed {res.data[0]['full_name']} from roster."}


@router.post("/import-csv")
def admin_import_csv(payload: AdminCsvImportRequest):
    raw = payload.csv_content.strip()
    if not raw:
        raise HTTPException(status_code=400, detail="CSV content is empty.")

    reader = csv.reader(io.StringIO(raw))
    rows = [r for r in reader if any(c.strip() for c in r)]
    if not rows:
        raise HTTPException(status_code=400, detail="No valid CSV lines found.")

    first_col = rows[0][0].strip().lower()
    if first_col in ("student_id", "id", "student id"):
        rows = rows[1:]

    existing_res = supabase.table("seminar_attendees").select("student_id, email").execute()
    existing_ids = {str(r["student_id"]).strip().lower() for r in (existing_res.data or [])}
    existing_emails = {str(r["email"]).strip().lower() for r in (existing_res.data or [])}

    to_insert = []
    skipped = 0

    for row in rows:
        if len(row) < 4:
            skipped += 1
            continue
        sid = row[0].strip()
        name = row[1].strip()
        email = row[2].strip().lower()
        section = row[3].strip()

        if not sid or not name or "@" not in email or sid.lower() in existing_ids or email in existing_emails:
            skipped += 1
            continue

        existing_ids.add(sid.lower())
        existing_emails.add(email)
        to_insert.append(
            {
                "student_id": sid,
                "full_name": name,
                "email": email,
                "program_section": section,
                "registration_type": "PRE_REGISTERED",
                "is_present": False,
                "is_paid": False,
                "amount_paid": 0.0,
                "payment_method": "NONE",
            }
        )

    inserted = 0
    if to_insert:
        ins = supabase.table("seminar_attendees").insert(to_insert).execute()
        inserted = len(ins.data or [])

    return {
        "message": f"Imported {inserted} pre-registered records ({skipped} skipped).",
        "inserted": inserted,
        "skipped": skipped,
    }