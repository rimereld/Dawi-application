from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import Appointment, User
from ..schemas import AppointmentCreate, AppointmentOut, AppointmentUpdate

router = APIRouter(prefix="/appointments", tags=["appointments"])


def _get_owned_appointment(appointment_id: str, current_user: User, db: Session) -> Appointment:
    appointment = db.get(Appointment, appointment_id)
    if not appointment or appointment.user_id != current_user.id:
        raise HTTPException(404, "Appointment not found")
    return appointment


@router.get("", response_model=list[AppointmentOut])
def list_appointments(
    status: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Appointment).filter(Appointment.user_id == current_user.id)
    if status:
        query = query.filter(Appointment.status == status)
    return query.order_by(Appointment.date.asc(), Appointment.time.asc()).all()


@router.get("/{appointment_id}", response_model=AppointmentOut)
def get_appointment(
    appointment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_owned_appointment(appointment_id, current_user, db)


@router.post("", response_model=AppointmentOut)
def create_appointment(
    body: AppointmentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    appointment = Appointment(user_id=current_user.id, **body.model_dump())
    db.add(appointment)
    db.commit()
    db.refresh(appointment)
    return appointment


@router.put("/{appointment_id}", response_model=AppointmentOut)
def update_appointment(
    appointment_id: str,
    body: AppointmentUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    appointment = _get_owned_appointment(appointment_id, current_user, db)
    for field, value in body.model_dump().items():
        setattr(appointment, field, value)
    db.commit()
    db.refresh(appointment)
    return appointment


@router.delete("/{appointment_id}", status_code=204)
def delete_appointment(
    appointment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    appointment = _get_owned_appointment(appointment_id, current_user, db)
    db.delete(appointment)
    db.commit()
