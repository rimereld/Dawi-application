from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    first_name: str = ""
    last_name: str = ""
    phone: str = ""
    preferred_language: str = "English"

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str
    first_name: str
    last_name: str
    phone: str
    preferred_language: str
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------------------------------------------------------------------------
# Health profile
# ---------------------------------------------------------------------------


class HealthProfileIn(BaseModel):
    date_of_birth: str = ""
    blood_group: str = ""
    allergies: str = ""
    conditions: str = ""
    emergency_contact_name: str = ""
    emergency_contact_phone: str = ""


class HealthProfileOut(HealthProfileIn):
    model_config = ConfigDict(from_attributes=True)
    id: str


# ---------------------------------------------------------------------------
# Doctors
# ---------------------------------------------------------------------------


class DoctorIn(BaseModel):
    name: str
    specialty: str = ""
    hospital: str = ""
    phone: str = ""


class DoctorOut(DoctorIn):
    model_config = ConfigDict(from_attributes=True)
    id: str


# ---------------------------------------------------------------------------
# Medications
# ---------------------------------------------------------------------------


class MedicationBase(BaseModel):
    name: str
    form: str = ""
    dose: str = ""
    frequency: str = ""
    timing: str = ""
    doctor_name: str = ""
    start_date: str = ""
    end_date: str = ""
    status: str = "active"
    confirmed: bool = True


class MedicationOut(MedicationBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
    document_id: str | None = None


class MedicationUpdate(BaseModel):
    id: str | None = None
    name: str
    form: str = ""
    dose: str = ""
    frequency: str = ""
    timing: str = ""
    doctor_name: str = ""
    start_date: str = ""
    end_date: str = ""
    status: str = "active"
    confirmed: bool = True


class MedicationCreate(MedicationBase):
    """Used for standalone "Add medication" (spec section 13), not tied to
    a scanned document."""


# ---------------------------------------------------------------------------
# Documents (prescriptions, lab reports, medical reports, certificates, imaging)
# ---------------------------------------------------------------------------


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    document_type: str
    doctor_name: str
    clinic_name: str
    document_date: str
    file_path: str
    file_url: str = ""
    raw_ocr_text: str
    ai_summary: str = ""
    created_at: datetime
    medications: list[MedicationOut] = []


class ScanResponse(BaseModel):
    """Returned right after a document is scanned/uploaded, before the
    user confirms/edits the extracted information."""

    document_id: str
    document_type: str
    raw_ocr_text: str
    ai_summary: str = ""
    medications: list[MedicationOut]
    doctor_name: str = ""
    clinic_name: str = ""
    file_url: str = ""


class ConfirmDocumentRequest(BaseModel):
    document_type: str = "prescription"
    doctor_name: str = ""
    clinic_name: str = ""
    document_date: str = ""
    medications: list[MedicationUpdate] = []


class AiExplanationTerm(BaseModel):
    term: str
    explanation: str


class AiMedicationExplanation(BaseModel):
    name: str
    dosage: str = ""
    frequency: str = ""
    duration: str = ""
    purpose: str = ""


class AiExplanationResponse(BaseModel):
    """The dedicated "AI Explanation" page's content (spec section 11)."""

    simple_explanation: str
    medical_terms: list[AiExplanationTerm] = []
    medication_explanations: list[AiMedicationExplanation] = []
    important_information: list[str] = []
    questions_for_doctor: list[str] = []
    disclaimer: str = (
        "This information is for educational purposes and does not replace "
        "advice from a healthcare professional."
    )


# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------


class AppointmentBase(BaseModel):
    doctor_id: str | None = None
    specialty: str = ""
    date: str = ""
    time: str = ""
    location: str = ""
    reason: str = ""
    status: str = "upcoming"


class AppointmentOut(AppointmentBase):
    model_config = ConfigDict(from_attributes=True)
    id: str


class AppointmentCreate(AppointmentBase):
    pass


class AppointmentUpdate(AppointmentBase):
    pass


# ---------------------------------------------------------------------------
# Chat / AI assistant
# ---------------------------------------------------------------------------


class ChatRequest(BaseModel):
    message: str
    document_id: str | None = None
    # Optional client-side history for stateless callers; the backend also
    # persists + reloads history by document_id when provided.
    history: list[dict] | None = None


class ChatResponse(BaseModel):
    reply: str


# ---------------------------------------------------------------------------
# Medical record / AI health summary aggregates
# ---------------------------------------------------------------------------


class MedicalRecordResponse(BaseModel):
    """Aggregated view for the "Medical Record / My Health" page (section 12)."""

    health_profile: HealthProfileOut | None
    active_medications: list[MedicationOut]
    past_medications: list[MedicationOut]
    doctors: list[DoctorOut]
    recent_documents: list[DocumentOut]


class AiHealthSummaryResponse(BaseModel):
    """The "AI Health Summary" page's content (section 21)."""

    current_situation: str
    current_treatments: list[str]
    recent_analyses: list[str]
    upcoming_appointments: list[str]
    important_information: list[str]
    general_recommendations: list[str]
    generated_note: str = "Generated from your validated medical information."
