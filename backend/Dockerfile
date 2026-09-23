# --- Rx Scanner backend image -------------------------------------------
# Python + FastAPI + Tesseract OCR, ready to run with uvicorn.

FROM python:3.12-slim

# Tesseract OCR engine (the `pytesseract` Python package only talks to it,
# the actual OCR binary has to be installed at the OS level).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tesseract-ocr \
        libtesseract-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first so this layer is cached across rebuilds
# that only change application code.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App source
COPY app ./app

# Uploaded prescription images and the SQLite DB file are written here;
# both are mounted as volumes in docker-compose.yml so they persist across
# container restarts/rebuilds.
RUN mkdir -p /app/app/uploads /app/data

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
