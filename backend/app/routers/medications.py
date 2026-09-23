from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import Medication, User
from ..schemas import MedicationCreate, MedicationOut, MedicationUpdate

router = APIRouter(prefix="/medications", tags=["medications"])


def _get_owned_medication(medication_id: str, current_user: User, db: Session) -> Medication:
    medication = db.get(Medication, medication_id)
    if not medication or medication.user_id != current_user.id:
        raise HTTPException(404, "Medication not found")
    return medication


@router.get("", response_model=list[MedicationOut])
def list_medications(
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List the user's medications, optionally filtered by status
    (active | completed | upcoming) — used for the Medications page's
    category tabs."""
    query = db.query(Medication).filter(Medication.user_id == current_user.id)
    if status:
        query = query.filter(Medication.status == status)
    return query.all()


@router.get("/{medication_id}", response_model=MedicationOut)
def get_medication(
    medication_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_owned_medication(medication_id, current_user, db)


@router.post("", response_model=MedicationOut)
def create_medication(
    body: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Standalone "Add medication" (spec section 13), not tied to a
    scanned document."""
    medication = Medication(user_id=current_user.id, **body.model_dump())
    db.add(medication)
    db.commit()
    db.refresh(medication)
    return medication


@router.put("/{medication_id}", response_model=MedicationOut)
def update_medication(
    medication_id: str,
    body: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    medication = _get_owned_medication(medication_id, current_user, db)
    for field, value in body.model_dump(exclude={"id"}).items():
        setattr(medication, field, value)
    db.commit()
    db.refresh(medication)
    return medication


@router.delete("/{medication_id}", status_code=204)
def delete_medication(
    medication_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    medication = _get_owned_medication(medication_id, current_user, db)
    db.delete(medication)
    db.commit()
