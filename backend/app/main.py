from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .database import Base, engine
from .routers import appointments, auth, chat, doctors, documents, health, medications

settings = get_settings()

# Create tables on startup. For production, replace with Alembic migrations.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Rx Scanner / Health App API",
    description=(
        "Backend for the personal health app: multi-user auth, OCR + AI "
        "parsing of medical documents (prescriptions, lab reports, medical "
        "reports, certificates, imaging), an AI Health Assistant, "
        "medications, appointments, doctors, and a health profile."
    ),
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(documents.router)
app.include_router(medications.router)
app.include_router(appointments.router)
app.include_router(doctors.router)
app.include_router(health.router)
app.include_router(chat.router)

# Serve uploaded document files so the Flutter app can display them
# (e.g. GET /uploads/<filename>).
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")


@app.get("/health-check")
def health_check():
    return {"status": "ok"}
