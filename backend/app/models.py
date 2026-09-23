import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String)
    first_name: Mapped[str] = mapped_column(String, default="")
    last_name: Mapped[str] = mapped_column(String, default="")
    phone: Mapped[str] = mapped_column(String, default="")
    preferred_language: Mapped[str] = mapped_column(String, default="English")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    documents: Mapped[list["Document"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    medications: Mapped[list["Medication"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    appointments: Mapped[list["Appointment"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    doctors: Mapped[list["Doctor"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    health_profile: Mapped["HealthProfile | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class HealthProfile(Base):
    """Optional health info the user can fill in after registration
    (spec section 4 — "Initial Health Profile"). One row per user."""

    __tablename__ = "health_profiles"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    date_of_birth: Mapped[str] = mapped_column(String, default="")  # "YYYY-MM-DD" or ""
    blood_group: Mapped[str] = mapped_column(String, default="")
    allergies: Mapped[str] = mapped_column(String, default="")  # free text, comma-separated
    conditions: Mapped[str] = mapped_column(String, default="")  # free text, comma-separated
    emergency_contact_name: Mapped[str] = mapped_column(String, default="")
    emergency_contact_phone: Mapped[str] = mapped_column(String, default="")

    user: Mapped["User"] = relationship(back_populates="health_profile")


class Doctor(Base):
    __tablename__ = "doctors"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String, default="")
    specialty: Mapped[str] = mapped_column(String, default="")
    hospital: Mapped[str] = mapped_column(String, default="")
    phone: Mapped[str] = mapped_column(String, default="")

    user: Mapped["User"] = relationship(back_populates="doctors")
    appointments: Mapped[list["Appointment"]] = relationship(back_populates="doctor")


class Document(Base):
    """A medical document the user scanned or uploaded: prescription, lab
    report, medical report, certificate, imaging report, or other. Generalizes
    what used to be a prescription-only model."""

    __tablename__ = "documents"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    document_type: Mapped[str] = mapped_column(String, default="prescription")
    # prescription | lab_report | medical_report | certificate | imaging | other
    doctor_name: Mapped[str] = mapped_column(String, default="")
    clinic_name: Mapped[str] = mapped_column(String, default="")
    document_date: Mapped[str] = mapped_column(String, default="")  # "YYYY-MM-DD" or ""
    file_path: Mapped[str] = mapped_column(String, default="")
    raw_ocr_text: Mapped[str] = mapped_column(String, default="")
    ai_summary: Mapped[str] = mapped_column(String, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="documents")
    medications: Mapped[list["Medication"]] = relationship(
        back_populates="document", cascade="all, delete-orphan"
    )


class Medication(Base):
    __tablename__ = "medications"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    document_id: Mapped[str | None] = mapped_column(ForeignKey("documents.id"), nullable=True)
    name: Mapped[str] = mapped_column(String, default="")
    form: Mapped[str] = mapped_column(String, default="")
    dose: Mapped[str] = mapped_column(String, default="")
    frequency: Mapped[str] = mapped_column(String, default="")
    timing: Mapped[str] = mapped_column(String, default="")
    doctor_name: Mapped[str] = mapped_column(String, default="")
    start_date: Mapped[str] = mapped_column(String, default="")
    end_date: Mapped[str] = mapped_column(String, default="")
    status: Mapped[str] = mapped_column(String, default="active")  # active | completed | upcoming
    confirmed: Mapped[bool] = mapped_column(Boolean, default=True)

    user: Mapped["User"] = relationship(back_populates="medications")
    document: Mapped["Document | None"] = relationship(back_populates="medications")


class Appointment(Base):
    __tablename__ = "appointments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    doctor_id: Mapped[str | None] = mapped_column(ForeignKey("doctors.id"), nullable=True)
    specialty: Mapped[str] = mapped_column(String, default="")
    date: Mapped[str] = mapped_column(String, default="")  # "YYYY-MM-DD"
    time: Mapped[str] = mapped_column(String, default="")  # "HH:MM"
    location: Mapped[str] = mapped_column(String, default="")
    reason: Mapped[str] = mapped_column(String, default="")
    status: Mapped[str] = mapped_column(String, default="upcoming")  # upcoming | completed | cancelled

    user: Mapped["User"] = relationship(back_populates="appointments")
    doctor: Mapped["Doctor | None"] = relationship(back_populates="appointments")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    document_id: Mapped[str | None] = mapped_column(ForeignKey("documents.id"), nullable=True)
    role: Mapped[str] = mapped_column(String)  # "user" | "assistant"
    content: Mapped[str] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
