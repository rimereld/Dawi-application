"""Wraps the Anthropic API for three jobs:

1. Turning noisy OCR/extracted text from any medical document (prescription,
   lab report, medical report, certificate, imaging report) into structured
   data: medications (if any), a short summary, doctor/clinic/date.
2. Producing the dedicated "AI Explanation" page's content for one document:
   a plain-language explanation, medical term glossary, per-medication
   explanation, important instructions, and suggested questions for the
   user's doctor.
3. Powering the "AI Assistant" conversational endpoint, grounded in either
   one specific document or a general summary of the user's medications /
   appointments.

Every prompt is written to keep facts, explanations, and general advice
separate, and to never present AI output as a confirmed diagnosis — matching
the app's core safety requirement.
"""
from __future__ import annotations

import json
from typing import Any

from anthropic import Anthropic

from ..config import get_settings

settings = get_settings()
_client: Anthropic | None = None


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        if not settings.anthropic_api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY is not set. Add it to your .env file."
            )
        _client = Anthropic(api_key=settings.anthropic_api_key)
    return _client


def _extract_text(response: Any) -> str:
    return next((b.text for b in response.content if b.type == "text"), "").strip()


def _parse_json(text_block: str, fallback: dict[str, Any]) -> dict[str, Any]:
    try:
        return json.loads(text_block)
    except json.JSONDecodeError:
        # Model occasionally wraps JSON in fences despite instructions;
        # strip them and retry once before giving up.
        cleaned = text_block.strip().strip("`")
        if cleaned.startswith("json"):
            cleaned = cleaned[4:]
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            return fallback


# ---------------------------------------------------------------------------
# 1. Document parsing (OCR text -> structured data)
# ---------------------------------------------------------------------------

PARSE_SYSTEM_PROMPT = """\
You are a medical document parser. You will be given raw, possibly messy \
OCR/extracted text from a medical document. First decide the document type, \
then return ONLY a JSON object (no prose, no markdown fences) with this \
exact shape:

{
  "document_type": "prescription | lab_report | medical_report | certificate | imaging | other",
  "doctor_name": "string, empty if unknown",
  "clinic_name": "string, empty if unknown",
  "document_date": "YYYY-MM-DD if found, else empty string",
  "summary": "One short, plain-language sentence summarizing what this document is and its main content.",
  "medications": [
    {
      "name": "Full generic or brand name with strength, e.g. 'Paracetamol 500 mg'",
      "form": "Tablet | Capsule | Drops | Syrup | Injection | Other",
      "dose": "e.g. '1 tablet'",
      "frequency": "e.g. 'Thrice daily', 'Once daily'",
      "timing": "e.g. 'After meals', 'At night', 'Before meals'"
    }
  ]
}

Only include a "medications" entry when the document is a prescription (or \
otherwise clearly lists medications to take) — for a lab report, imaging \
report, certificate, or other non-prescription document, return an empty \
"medications" list.

Expand common shorthand: OD=once daily, BID/BD=twice daily, TDS/TID=thrice \
daily, QID=four times daily, HS=at night, AC=before meals, PC=after meals. \
If a field is genuinely unknown, use an empty string rather than guessing. \
Never include explanations outside the JSON object.
"""


def parse_document_text(raw_text: str) -> dict[str, Any]:
    """Send raw OCR/extracted text to Claude and get back structured data
    for any supported medical document type."""
    client = _get_client()
    response = client.messages.create(
        model=settings.anthropic_model,
        max_tokens=1024,
        system=PARSE_SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": f"Extracted text from the document:\n\n{raw_text}",
            }
        ],
    )
    return _parse_json(
        _extract_text(response),
        {
            "document_type": "other",
            "doctor_name": "",
            "clinic_name": "",
            "document_date": "",
            "summary": "",
            "medications": [],
        },
    )


# ---------------------------------------------------------------------------
# 2. Dedicated AI Explanation page
# ---------------------------------------------------------------------------

EXPLAIN_SYSTEM_PROMPT = """\
You are a patient-education assistant explaining ONE medical document back \
to the patient who owns it, in simple, reassuring, non-diagnostic language. \
Return ONLY a JSON object (no prose, no markdown fences) with this exact shape:

{
  "simple_explanation": "2-4 sentences explaining what this document is and what it says, in plain language a non-medical person can follow.",
  "medical_terms": [
    {"term": "the exact medical term as it appears", "explanation": "one simple sentence"}
  ],
  "medication_explanations": [
    {"name": "...", "dosage": "...", "frequency": "...", "duration": "...", "purpose": "general, non-diagnostic reason this type of medicine is commonly used, only if reliably inferable — else empty string"}
  ],
  "important_information": ["short, important instructions or warnings actually present in the document"],
  "questions_for_doctor": ["2-4 thoughtful questions the patient could ask their doctor about this document"]
}

Rules:
- Only explain terms that actually appear in the document text given to you.
- Never state a diagnosis or claim to know the patient's condition.
- Keep "purpose" general (e.g. "commonly used to reduce fever and pain") — \
never claim it treats this specific patient's condition.
- If a section has nothing relevant, return an empty list for it.
"""


def explain_document(
    raw_text: str,
    ai_summary: str,
    medications: list[dict[str, str]] | None = None,
) -> dict[str, Any]:
    """Generate the structured content for the dedicated "AI Explanation"
    page for one document."""
    client = _get_client()
    context = f"Document text:\n{raw_text}\n\nPrior summary: {ai_summary}"
    if medications:
        med_lines = "\n".join(
            f"- {m.get('name', '')}: {m.get('dose', '')}, {m.get('frequency', '')}, {m.get('timing', '')}"
            for m in medications
        )
        context += f"\n\nExtracted medications:\n{med_lines}"

    response = client.messages.create(
        model=settings.anthropic_model,
        max_tokens=1200,
        system=EXPLAIN_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": context}],
    )
    return _parse_json(
        _extract_text(response),
        {
            "simple_explanation": "",
            "medical_terms": [],
            "medication_explanations": [],
            "important_information": [],
            "questions_for_doctor": [],
        },
    )


# ---------------------------------------------------------------------------
# 3. AI Assistant chat
# ---------------------------------------------------------------------------

CHAT_SYSTEM_PROMPT = """\
You are the "AI Health Assistant" inside a personal health app. You help \
users understand their own medical documents, medications, and upcoming \
appointments — all data explicitly provided to you below, never invented.

Rules:
- You are not a substitute for a licensed doctor. For anything about dosing \
  changes, side effects that sound serious, or personal medical decisions, \
  tell the user to consult their doctor or pharmacist.
- Clearly distinguish facts drawn from the user's data (cite it, e.g. "Your \
  prescription from Dr. X says...") from general explanations or suggestions.
- Never state or imply a diagnosis.
- Keep answers concise, warm, and easy to understand for a non-medical \
  audience.
- If no relevant data was provided for a question, say so plainly instead \
  of guessing.
"""


def chat_reply(
    message: str,
    history: list[dict] | None = None,
    document_context: str | None = None,
    general_context: str | None = None,
) -> str:
    """Get a conversational reply from Claude, grounded in either one
    specific document's contents or a general summary of the user's
    medications/appointments (whichever is provided)."""
    client = _get_client()

    system = CHAT_SYSTEM_PROMPT
    if document_context:
        system += f"\n\nThe user is asking about this specific document:\n{document_context}"
    elif general_context:
        system += f"\n\nSummary of the user's current health data:\n{general_context}"

    messages = list(history or [])
    messages.append({"role": "user", "content": message})

    response = client.messages.create(
        model=settings.anthropic_model,
        max_tokens=600,
        system=system,
        messages=messages,
    )
    return _extract_text(response)


# ---------------------------------------------------------------------------
# 4. AI Health Summary page
# ---------------------------------------------------------------------------

HEALTH_SUMMARY_SYSTEM_PROMPT = """\
You generate the content for a patient's "AI Health Summary" page, using \
ONLY the validated data provided below — never invent facts. Return ONLY a \
JSON object (no prose, no markdown fences) with this exact shape:

{
  "current_situation": "2-3 plain-language sentences summarizing the user's current health data (or noting there isn't much yet).",
  "current_treatments": ["one line per active medication/treatment"],
  "recent_analyses": ["one line per recent lab result/document, if any"],
  "upcoming_appointments": ["one line per upcoming appointment, if any"],
  "important_information": ["allergies and documented conditions worth highlighting"],
  "general_recommendations": ["2-4 general, non-diagnostic lifestyle/health tips relevant to the data given"]
}

Never present a recommendation as a confirmed medical necessity, and never \
diagnose. If a section has no data, return an empty list with an honest tone \
in current_situation (e.g. "You haven't added any health information yet.").
"""


def generate_health_summary(data_context: str) -> dict[str, Any]:
    client = _get_client()
    response = client.messages.create(
        model=settings.anthropic_model,
        max_tokens=900,
        system=HEALTH_SUMMARY_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": data_context}],
    )
    return _parse_json(
        _extract_text(response),
        {
            "current_situation": "",
            "current_treatments": [],
            "recent_analyses": [],
            "upcoming_appointments": [],
            "important_information": [],
            "general_recommendations": [],
        },
    )
