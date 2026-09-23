# HealthKeep — FastAPI Backend

Backend for HealthKeep, a personal health app: multi-user JWT auth, OCR +
AI parsing of medical documents (prescriptions, lab reports, medical
reports, certificates, imaging), an AI Health Assistant, medications,
appointments, doctors, and an optional health profile.

## Stack

- **FastAPI** — HTTP API
- **SQLAlchemy + SQLite** — storage (swap `DATABASE_URL` for Postgres/MySQL in production)
- **JWT auth** (`python-jose` + `passlib[bcrypt]`) — email/password accounts, per-user data
- **Tesseract OCR** (`pytesseract`) — reads text off photographed documents
- **pypdf** — extracts the text layer from uploaded PDF documents
- **Anthropic API (Claude)** — parses documents into structured data, and powers the AI Explanation, AI Assistant, and AI Health Summary features

## Setup

1. **Install Tesseract OCR** (the OCR engine itself, separate from the Python package):
   - macOS: `brew install tesseract`
   - Ubuntu/Debian: `sudo apt install tesseract-ocr`
   - Windows: [UB-Mannheim installer](https://github.com/UB-Mannheim/tesseract/wiki)

2. **Create a virtual environment and install dependencies:**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate   # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Then edit `.env` and set:
   - `ANTHROPIC_API_KEY` — from [console.anthropic.com](https://console.anthropic.com)
   - `JWT_SECRET` — a long random string (e.g. `openssl rand -hex 32`); the default is only for local dev
   - `TESSERACT_CMD` — only if Tesseract isn't on your PATH

4. **Run the server:**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

5. **Explore the interactive API docs** at `http://localhost:8000/docs`.

## Auth

Every endpoint except `/auth/register`, `/auth/login`, `/health-check`, and
`/docs` requires a JWT: register or log in to get an `access_token`, then
send it as `Authorization: Bearer <token>` on every other request. All data
(documents, medications, appointments, doctors, health profile) is scoped
to the authenticated user — there's no cross-user access.

## API overview

| Method | Path | Description |
|---|---|---|
| `POST` | `/auth/register` | Create an account, returns a JWT + user |
| `POST` | `/auth/login` | Log in, returns a JWT + user |
| `GET` | `/auth/me` | Current user's profile |
| `POST` | `/documents/scan` | Upload a document (image or PDF). Runs OCR/text-extraction + AI parsing, saves a draft, returns extracted info |
| `GET` | `/documents` | List the user's documents (optional `?document_type=`) |
| `GET` | `/documents/{id}` | Get one document with its medications |
| `PATCH` | `/documents/{id}/confirm` | Save the user's reviewed/edited info (the OCR Analysis screen's confirm step) |
| `DELETE` | `/documents/{id}` | Delete a document |
| `POST` | `/documents/{id}/explain` | Generate the AI Explanation content for one document |
| `GET`/`POST`/`PUT`/`DELETE` | `/medications`, `/medications/{id}` | Standalone medication CRUD, filterable by `?status=active|completed|upcoming` |
| `GET`/`POST`/`PUT`/`DELETE` | `/appointments`, `/appointments/{id}` | Appointment CRUD, filterable by `?status=` |
| `GET`/`POST`/`PUT`/`DELETE` | `/doctors`, `/doctors/{id}` | Doctor CRUD |
| `GET`/`PUT` | `/health/profile` | Get/create/update the optional health profile |
| `GET` | `/health/medical-record` | Aggregated view: profile + medications + doctors + recent documents |
| `GET` | `/health/summary` | AI-generated "AI Health Summary" content |
| `POST` | `/chat` | Ask the AI Assistant. Pass `document_id` to ground it in one document; otherwise it's grounded in active medications + upcoming appointments |
| `GET` | `/chat/history` | Chat history (optional `?document_id=`) |
| `GET` | `/uploads/{filename}` | Static file serving for uploaded documents |
| `GET` | `/health-check` | Health check (no auth required) |

### Example: register, then scan a document

```bash
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"supersecret123","first_name":"Jane"}'
# → copy the access_token from the response

curl -X POST http://localhost:8000/documents/scan \
  -H "Authorization: Bearer <token>" \
  -F "file=@/path/to/document.jpg"
```

## Project structure

```
app/
  main.py                    # FastAPI app, CORS, router registration
  config.py                  # Settings loaded from .env (incl. JWT settings)
  database.py                # SQLAlchemy engine/session
  auth.py                    # Password hashing, JWT creation/verification, get_current_user dependency
  models.py                  # ORM models: User, HealthProfile, Doctor, Document, Medication, Appointment, ChatMessage
  schemas.py                 # Pydantic request/response models
  routers/
    auth.py                  # register / login / me
    documents.py             # scan / list / get / confirm / delete / explain
    medications.py           # CRUD
    appointments.py          # CRUD
    doctors.py                # CRUD
    health.py                 # profile / medical-record / summary
    chat.py                    # AI Assistant + history
  services/
    ocr_service.py             # Tesseract OCR (images) + pypdf text extraction (PDFs)
    ai_service.py               # Anthropic API calls: document parsing, AI explanation, chat, health summary
  uploads/                     # Uploaded document files land here
requirements.txt
.env.example
```

## Known simplifications (MVP scope)

This backend covers the MVP screen list from the app spec. A few things
are intentionally left as clear next steps rather than half-built:

- **No password reset emails** — there's no `/auth/forgot-password`
  endpoint yet; the frontend's forgot-password screen is UI-only.
- **No data export / account deletion endpoints** — the Privacy screen's
  buttons for these show a "not wired up yet" message.
- **PDF OCR only reads the embedded text layer** — a PDF that's just a
  scanned image with no text layer returns little or nothing. Rasterizing
  PDF pages to run Tesseract on them (e.g. via `pdf2image`) is a reasonable
  next step if that's common for your users.
- **No push/local notifications** — reminders are stored as data
  (medications, appointments) but nothing schedules an actual notification
  yet.
- **No Alembic migrations** — tables are created via
  `Base.metadata.create_all` on startup. If you already had a database
  from an earlier version of this app, delete it (or `docker compose down
  -v`) so it's recreated with the current schema.
