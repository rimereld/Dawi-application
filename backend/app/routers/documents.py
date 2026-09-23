import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..config import get_settings
from ..database import get_db
from ..models import Document, Medication, User
from ..schemas import (
    AiExplanationResponse,
    ConfirmDocumentRequest,
    DocumentOut,
    MedicationOut,
    ScanResponse,
)
from ..services import ai_service, ocr_service

router = APIRouter(prefix="/documents", tags=["documents"])
settings = get_settings()

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "application/pdf",
}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".pdf"}


def _is_allowed_upload(content_type: str | None, filename: str | None) -> bool:
    """Accept the file if either its declared Content-Type or its filename
    extension matches a supported document type. Some clients (older
    browsers, some mobile upload libraries) send a generic or missing
    Content-Type such as 'application/octet-stream', so relying on
    Content-Type alone rejects perfectly valid uploads."""
    if content_type in ALLOWED_CONTENT_TYPES:
        return True
    ext = os.path.splitext(filename or "")[1].lower()
    return ext in ALLOWED_EXTENSIONS


def _file_url(file_path: str) -> str:
    """Turn a stored file path (e.g. 'app/uploads/xyz.jpg') into the public
    URL the static file mount serves it at (e.g. '/uploads/xyz.jpg')."""
    if not file_path:
        return ""
    filename = os.path.basename(file_path)
    return f"/uploads/{filename}"


def _to_document_out(document: Document) -> DocumentOut:
    out = DocumentOut.model_validate(document)
    out.file_url = _file_url(document.file_path)
    return out


@router.post("/scan", response_model=ScanResponse)
async def scan_document(
    file: UploadFile,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Upload a medical document (photo or PDF) — a prescription, lab
    report, medical report, certificate, or imaging report. Extracts text
    (OCR for images, text layer for PDFs), asks the AI model to classify
    the document and structure its contents, and saves a draft Document row
    which the client can then edit and finalize via
    PATCH /documents/{id}/confirm.
    """
    if not _is_allowed_upload(file.content_type, file.filename):
        raise HTTPException(400, f"Unsupported file type: {file.content_type} ({file.filename})")

    ext = os.path.splitext(file.filename or "")[1].lower() or (
        ".pdf" if file.content_type == "application/pdf" else ".jpg"
    )
    saved_name = f"{uuid.uuid4()}{ext}"
    saved_path = os.path.join(settings.upload_dir, saved_name)

    contents = await file.read()
    with open(saved_path, "wb") as f:
        f.write(contents)

    try:
        raw_text = ocr_service.extract_text(saved_path)
    except RuntimeError as exc:
        raise HTTPException(500, str(exc)) from exc

    try:
        parsed = ai_service.parse_document_text(raw_text)
    except RuntimeError as exc:
        raise HTTPException(500, str(exc)) from exc

    document = Document(
        user_id=current_user.id,
        document_type=parsed.get("document_type", "other"),
        doctor_name=parsed.get("doctor_name", ""),
        clinic_name=parsed.get("clinic_name", ""),
        document_date=parsed.get("document_date", ""),
        file_path=saved_path,
        raw_ocr_text=raw_text,
        ai_summary=parsed.get("summary", ""),
    )
    db.add(document)
    db.flush()  # get document.id before creating children

    medications = []
    for med in parsed.get("medications", []):
        m = Medication(
            user_id=current_user.id,
            document_id=document.id,
            name=med.get("name", ""),
            form=med.get("form", ""),
            dose=med.get("dose", ""),
            frequency=med.get("frequency", ""),
            timing=med.get("timing", ""),
            doctor_name=document.doctor_name,
            status="active",
            confirmed=True,
        )
        db.add(m)
        medications.append(m)

    db.commit()
    db.refresh(document)

    return ScanResponse(
        document_id=document.id,
        document_type=document.document_type,
        raw_ocr_text=raw_text,
        ai_summary=document.ai_summary,
        medications=[MedicationOut.model_validate(m) for m in medications],
        doctor_name=document.doctor_name,
        clinic_name=document.clinic_name,
        file_url=_file_url(document.file_path),
    )


@router.get("", response_model=list[DocumentOut])
def list_documents(
    document_type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List the current user's documents, newest first. Optionally filter
    by document_type (prescription | lab_report | medical_report |
    certificate | imaging | other)."""
    query = db.query(Document).filter(Document.user_id == current_user.id)
    if document_type:
        query = query.filter(Document.document_type == document_type)
    documents = query.order_by(Document.created_at.desc()).all()
    return [_to_document_out(d) for d in documents]


def _get_owned_document(document_id: str, current_user: User, db: Session) -> Document:
    document = db.get(Document, document_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(404, "Document not found")
    return document


@router.get("/{document_id}", response_model=DocumentOut)
def get_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    document = _get_owned_document(document_id, current_user, db)
    return _to_document_out(document)


@router.patch("/{document_id}/confirm", response_model=DocumentOut)
def confirm_document(
    document_id: str,
    body: ConfirmDocumentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Finalize a document after the user reviews/edits the extracted
    information on the OCR Analysis screen."""
    document = _get_owned_document(document_id, current_user, db)

    document.document_type = body.document_type or document.document_type
    document.doctor_name = body.doctor_name or document.doctor_name
    document.clinic_name = body.clinic_name or document.clinic_name
    document.document_date = body.document_date or document.document_date

    # Replace medication rows with the confirmed/edited set from the client.
    db.query(Medication).filter(Medication.document_id == document_id).delete()
    for med in body.medications:
        db.add(
            Medication(
                user_id=current_user.id,
                document_id=document_id,
                name=med.name,
                form=med.form,
                dose=med.dose,
                frequency=med.frequency,
                timing=med.timing,
                doctor_name=med.doctor_name or document.doctor_name,
                start_date=med.start_date,
                end_date=med.end_date,
                status=med.status,
                confirmed=med.confirmed,
            )
        )

    db.commit()
    db.refresh(document)
    return _to_document_out(document)


@router.delete("/{document_id}", status_code=204)
def delete_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    document = _get_owned_document(document_id, current_user, db)
    db.delete(document)
    db.commit()


@router.post("/{document_id}/explain", response_model=AiExplanationResponse)
def explain_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Generates the dedicated "AI Explanation" page content for one
    document: plain-language explanation, medical term glossary,
    medication explanations, important information, and questions to ask
    the user's doctor."""
    document = _get_owned_document(document_id, current_user, db)

    meds = [
        {"name": m.name, "dose": m.dose, "frequency": m.frequency, "timing": m.timing}
        for m in document.medications
    ]
    try:
        result = ai_service.explain_document(
            raw_text=document.raw_ocr_text,
            ai_summary=document.ai_summary,
            medications=meds,
        )
    except RuntimeError as exc:
        raise HTTPException(500, str(exc)) from exc

    return AiExplanationResponse(**result)
