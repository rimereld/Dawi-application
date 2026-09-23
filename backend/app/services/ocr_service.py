"""Text extraction for medical documents: images via Tesseract OCR, PDFs via
their embedded text layer.

Handwritten prescriptions are hard for any OCR engine to read perfectly —
the raw text produced here is passed to the AI parser service, which is far
more tolerant of noisy/partial output than a rules-based parser would be.
"""
from __future__ import annotations

import os

import pytesseract
from PIL import Image, ImageFilter, ImageOps
from pypdf import PdfReader

from ..config import get_settings

settings = get_settings()
if settings.tesseract_cmd:
    pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd


def _preprocess(image: Image.Image) -> Image.Image:
    """Light preprocessing to improve OCR accuracy on photographed notes:
    grayscale, autocontrast, and a mild sharpen filter."""
    gray = ImageOps.grayscale(image)
    contrasted = ImageOps.autocontrast(gray)
    sharpened = contrasted.filter(ImageFilter.SHARPEN)
    return sharpened


def _extract_from_image(image_path: str) -> str:
    try:
        image = Image.open(image_path)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Could not open image at {image_path}: {exc}") from exc

    processed = _preprocess(image)

    try:
        text = pytesseract.image_to_string(processed)
    except pytesseract.TesseractNotFoundError as exc:
        raise RuntimeError(
            "Tesseract OCR engine not found. Install it "
            "(e.g. `brew install tesseract` / `apt install tesseract-ocr` / "
            "the Windows installer) and set TESSERACT_CMD in .env if it's "
            "not on your PATH."
        ) from exc

    return text.strip()


def _extract_from_pdf(pdf_path: str) -> str:
    """Extracts the embedded text layer of a PDF. Note: this only reads text
    that's already selectable in the PDF — a PDF that's just a scanned image
    with no text layer will return little or nothing. Rasterizing PDF pages
    to run OCR on them is a reasonable next step if that's a common case for
    your users (e.g. via `pdf2image` + the image path above)."""
    try:
        reader = PdfReader(pdf_path)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Could not open PDF at {pdf_path}: {exc}") from exc

    pages_text = [page.extract_text() or "" for page in reader.pages]
    return "\n".join(pages_text).strip()


def extract_text(file_path: str) -> str:
    """Run text extraction on the given file and return the raw text.
    Dispatches to image OCR or PDF text extraction based on file extension.

    Raises:
        RuntimeError: if the engine for that file type isn't available/
            reachable, with a message pointing at how to fix it.
    """
    ext = os.path.splitext(file_path)[1].lower()
    if ext == ".pdf":
        return _extract_from_pdf(file_path)
    return _extract_from_image(file_path)
