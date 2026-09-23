from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import Appointment, Doctor, Document, HealthProfile, Medication, User
from ..schemas import (
    AiHealthSummaryResponse,
    DoctorOut,
    DocumentOut,
    HealthProfileIn,
    HealthProfileOut,
    MedicalRecordResponse,
    MedicationOut,
)
from ..services import ai_service

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/profile", response_model=HealthProfileOut | None)
def get_health_profile(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    profile = db.query(HealthProfile).filter(HealthProfile.user_id == current_user.id).first()
    return profile


@router.put("/profile", response_model=HealthProfileOut)
def upsert_health_profile(
    body: HealthProfileIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create or update the user's optional health profile (spec section 4:
    "Initial Health Profile" — skippable, so this endpoint doubles as both
    the initial save and later edits from the Medical Record page)."""
    profile = db.query(HealthProfile).filter(HealthProfile.user_id == current_user.id).first()
    if profile is None:
        profile = HealthProfile(user_id=current_user.id, **body.model_dump())
        db.add(profile)
    else:
        for field, value in body.model_dump().items():
            setattr(profile, field, value)
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/medical-record", response_model=MedicalRecordResponse)
def get_medical_record(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Aggregated view for the "Medical Record / My Health" page (section 12):
    personal info, medications (active/past), doctors, and recent documents."""
    profile = db.query(HealthProfile).filter(HealthProfile.user_id == current_user.id).first()
    active_meds = (
        db.query(Medication)
        .filter(Medication.user_id == current_user.id, Medication.status == "active")
        .all()
    )
    past_meds = (
        db.query(Medication)
        .filter(Medication.user_id == current_user.id, Medication.status == "completed")
        .all()
    )
    doctors = db.query(Doctor).filter(Doctor.user_id == current_user.id).all()
    recent_documents = (
        db.query(Document)
        .filter(Document.user_id == current_user.id)
        .order_by(Document.created_at.desc())
        .limit(5)
        .all()
    )

    return MedicalRecordResponse(
        health_profile=HealthProfileOut.model_validate(profile) if profile else None,
        active_medications=[MedicationOut.model_validate(m) for m in active_meds],
        past_medications=[MedicationOut.model_validate(m) for m in past_meds],
        doctors=[DoctorOut.model_validate(d) for d in doctors],
        recent_documents=[DocumentOut.model_validate(d) for d in recent_documents],
    )


@router.get("/summary", response_model=AiHealthSummaryResponse)
def get_ai_health_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """The "AI Health Summary" page (section 21): an AI-generated overview
    built strictly from the user's validated data."""
    profile = db.query(HealthProfile).filter(HealthProfile.user_id == current_user.id).first()
    active_meds = (
        db.query(Medication)
        .filter(Medication.user_id == current_user.id, Medication.status == "active")
        .all()
    )
    upcoming_appts = (
        db.query(Appointment)
        .filter(Appointment.user_id == current_user.id, Appointment.status == "upcoming")
        .order_by(Appointment.date.asc())
        .limit(5)
        .all()
    )
    recent_docs = (
        db.query(Document)
        .filter(Document.user_id == current_user.id)
        .order_by(Document.created_at.desc())
        .limit(5)
        .all()
    )

    lines = []
    if profile:
        if profile.allergies:
            lines.append(f"Allergies: {profile.allergies}")
        if profile.conditions:
            lines.append(f"Known conditions: {profile.conditions}")
        if profile.blood_group:
            lines.append(f"Blood group: {profile.blood_group}")
    if active_meds:
        lines.append("Active medications:")
        lines += [f"- {m.name}: {m.dose}, {m.frequency}, {m.timing}" for m in active_meds]
    if upcoming_appts:
        lines.append("Upcoming appointments:")
        lines += [f"- {a.specialty or 'Appointment'} on {a.date} at {a.time}" for a in upcoming_appts]
    if recent_docs:
        lines.append("Recent documents:")
        lines += [f"- {d.document_type}: {d.ai_summary}" for d in recent_docs if d.ai_summary]

    data_context = "\n".join(lines) if lines else "No health data has been added yet."

    try:
        result = ai_service.generate_health_summary(data_context)
    except RuntimeError as exc:
        raise HTTPException(500, str(exc)) from exc

    return AiHealthSummaryResponse(**result)
