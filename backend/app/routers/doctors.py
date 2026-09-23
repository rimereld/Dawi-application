from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import Doctor, User
from ..schemas import DoctorIn, DoctorOut

router = APIRouter(prefix="/doctors", tags=["doctors"])


def _get_owned_doctor(doctor_id: str, current_user: User, db: Session) -> Doctor:
    doctor = db.get(Doctor, doctor_id)
    if not doctor or doctor.user_id != current_user.id:
        raise HTTPException(404, "Doctor not found")
    return doctor


@router.get("", response_model=list[DoctorOut])
def list_doctors(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Doctor).filter(Doctor.user_id == current_user.id).all()


@router.post("", response_model=DoctorOut)
def create_doctor(
    body: DoctorIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    doctor = Doctor(user_id=current_user.id, **body.model_dump())
    db.add(doctor)
    db.commit()
    db.refresh(doctor)
    return doctor


@router.put("/{doctor_id}", response_model=DoctorOut)
def update_doctor(
    doctor_id: str,
    body: DoctorIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    doctor = _get_owned_doctor(doctor_id, current_user, db)
    for field, value in body.model_dump().items():
        setattr(doctor, field, value)
    db.commit()
    db.refresh(doctor)
    return doctor


@router.delete("/{doctor_id}", status_code=204)
def delete_doctor(
    doctor_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    doctor = _get_owned_doctor(doctor_id, current_user, db)
    db.delete(doctor)
    db.commit()
