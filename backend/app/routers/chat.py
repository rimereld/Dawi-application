from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import Appointment, ChatMessage, Document, Medication, User
from ..schemas import ChatRequest, ChatResponse
from ..services import ai_service

router = APIRouter(prefix="/chat", tags=["chat"])


def _build_document_context(document: Document) -> str:
    lines = [
        f"Document type: {document.document_type}",
        f"Doctor: {document.doctor_name or 'unknown'}",
        f"Clinic: {document.clinic_name or 'unknown'}",
        f"Date: {document.document_date or 'unknown'}",
        f"Summary: {document.ai_summary or 'none'}",
    ]
    if document.medications:
        lines.append("Medications:")
        lines += [f"- {m.name} ({m.form}): {m.dose}, {m.frequency}, {m.timing}" for m in document.medications]
    return "\n".join(lines)


def _build_general_context(user: User, db: Session) -> str | None:
    """Grounds the AI Assistant in the user's active medications and
    upcoming appointments when the chat isn't tied to one specific
    document (spec section 20's general "Health Assistant" mode)."""
    active_meds = (
        db.query(Medication).filter(Medication.user_id == user.id, Medication.status == "active").all()
    )
    upcoming_appts = (
        db.query(Appointment)
        .filter(Appointment.user_id == user.id, Appointment.status == "upcoming")
        .order_by(Appointment.date.asc())
        .limit(5)
        .all()
    )
    if not active_meds and not upcoming_appts:
        return None

    lines = []
    if active_meds:
        lines.append("Active medications:")
        lines += [f"- {m.name}: {m.dose}, {m.frequency}, {m.timing}" for m in active_meds]
    if upcoming_appts:
        lines.append("Upcoming appointments:")
        lines += [f"- {a.specialty or 'Appointment'} on {a.date} at {a.time}" for a in upcoming_appts]
    return "\n".join(lines)


@router.post("", response_model=ChatResponse)
def send_chat_message(
    body: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Ask the AI Assistant a question. Pass document_id to ground the
    answer in one specific document; otherwise the assistant is grounded
    in a summary of the user's active medications and upcoming
    appointments. Persists both the user message and the assistant's
    reply so a document's chat thread can be reloaded later.
    """
    document_context = None
    if body.document_id:
        document = db.get(Document, body.document_id)
        if not document or document.user_id != current_user.id:
            raise HTTPException(404, "Document not found")
        document_context = _build_document_context(document)

    general_context = None if document_context else _build_general_context(current_user, db)

    # Reload prior turns for this thread so the model has memory, unless
    # the client already sent its own `history`.
    history = body.history
    if history is None:
        query = db.query(ChatMessage).filter(ChatMessage.user_id == current_user.id)
        if body.document_id:
            query = query.filter(ChatMessage.document_id == body.document_id)
        else:
            query = query.filter(ChatMessage.document_id.is_(None))
        prior = query.order_by(ChatMessage.created_at.asc()).all()
        history = [{"role": m.role, "content": m.content} for m in prior]

    try:
        reply = ai_service.chat_reply(
            message=body.message,
            history=history,
            document_context=document_context,
            general_context=general_context,
        )
    except RuntimeError as exc:
        raise HTTPException(500, str(exc)) from exc

    db.add(ChatMessage(
        user_id=current_user.id,
        document_id=body.document_id,
        role="user",
        content=body.message,
    ))
    db.add(ChatMessage(
        user_id=current_user.id,
        document_id=body.document_id,
        role="assistant",
        content=reply,
    ))
    db.commit()

    return ChatResponse(reply=reply)


@router.get("/history")
def get_chat_history(
    document_id: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(ChatMessage).filter(ChatMessage.user_id == current_user.id)
    query = query.filter(ChatMessage.document_id == document_id) if document_id else query.filter(
        ChatMessage.document_id.is_(None)
    )
    messages = query.order_by(ChatMessage.created_at.asc()).all()
    return [{"role": m.role, "content": m.content} for m in messages]
