import os
import io
import logging
from pathlib import Path
from typing import Tuple, List

import cv2
import numpy as np
import pytesseract
from PIL import Image
import fitz  # PyMuPDF

from app.config import settings

logger = logging.getLogger(__name__)

# Configure Tesseract path
if settings.TESSERACT_CMD and Path(settings.TESSERACT_CMD).exists():
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD

# Supported file types
SUPPORTED_IMAGE_TYPES = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".tif", ".webp"}
SUPPORTED_TYPES = SUPPORTED_IMAGE_TYPES | {".pdf"}


def preprocess_image(image: np.ndarray) -> np.ndarray:
    """Apply OpenCV preprocessing to improve OCR accuracy."""
    # Convert to grayscale if needed
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image.copy()

    # Adaptive thresholding for better contrast
    thresh = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        11, 2
    )

    # Deskew
    coords = np.column_stack(np.where(thresh > 0))
    if len(coords) > 0:
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle
        if abs(angle) < 30:  # Only deskew if angle is reasonable
            (h, w) = thresh.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            thresh = cv2.warpAffine(thresh, M, (w, h),
                                    flags=cv2.INTER_CUBIC,
                                    borderMode=cv2.BORDER_REPLICATE)

    return thresh


def ocr_image_array(image_array: np.ndarray) -> Tuple[str, float]:
    """Run Tesseract OCR on a numpy image array. Returns (text, confidence)."""
    preprocessed = preprocess_image(image_array)

    # Get detailed data including confidence
    data = pytesseract.image_to_data(
        preprocessed,
        output_type=pytesseract.Output.DICT,
        config="--oem 3 --psm 6"
    )

    # Extract text and calculate average confidence
    words = []
    confidences = []
    for i, word in enumerate(data["text"]):
        conf = int(data["conf"][i])
        if conf > 0 and word.strip():
            words.append(word)
            confidences.append(conf)

    text = " ".join(words)
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0

    # Also get clean text with layout preserved
    clean_text = pytesseract.image_to_string(
        preprocessed,
        config="--oem 3 --psm 6"
    ).strip()

    return clean_text, round(avg_confidence, 2)


def process_image_file(file_bytes: bytes) -> Tuple[str, float, int]:
    """Process an image file. Returns (text, confidence, page_count)."""
    try:
        # Load with PIL then convert to OpenCV
        pil_image = Image.open(io.BytesIO(file_bytes))

        # Convert RGBA to RGB if needed
        if pil_image.mode in ("RGBA", "LA", "P"):
            pil_image = pil_image.convert("RGB")

        image_array = np.array(pil_image)
        # PIL is RGB, OpenCV is BGR
        if len(image_array.shape) == 3:
            image_array = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)

        text, confidence = ocr_image_array(image_array)
        return text, confidence, 1
    except Exception as e:
        logger.error(f"Image OCR error: {e}")
        raise ValueError(f"Failed to process image: {str(e)}")


def process_pdf_file(file_bytes: bytes) -> Tuple[str, float, int]:
    """Process a PDF file by rendering each page. Returns (text, confidence, page_count)."""
    try:
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        all_texts = []
        all_confidences = []
        page_count = len(doc)

        for page_num in range(page_count):
            page = doc[page_num]
            # Render at 300 DPI for better OCR quality
            mat = fitz.Matrix(300 / 72, 300 / 72)
            pix = page.get_pixmap(matrix=mat)
            img_bytes = pix.tobytes("png")

            pil_image = Image.open(io.BytesIO(img_bytes))
            image_array = np.array(pil_image)
            if len(image_array.shape) == 3:
                image_array = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)

            text, confidence = ocr_image_array(image_array)
            if text:
                all_texts.append(f"--- Page {page_num + 1} ---\n{text}")
                all_confidences.append(confidence)

        doc.close()

        combined_text = "\n\n".join(all_texts)
        avg_confidence = (
            sum(all_confidences) / len(all_confidences) if all_confidences else 0.0
        )
        return combined_text, round(avg_confidence, 2), page_count

    except Exception as e:
        logger.error(f"PDF OCR error: {e}")
        raise ValueError(f"Failed to process PDF: {str(e)}")


def process_file(file_bytes: bytes, filename: str) -> Tuple[str, float, int]:
    """Main entry point. Dispatches to image or PDF processor."""
    ext = Path(filename).suffix.lower()
    if ext not in SUPPORTED_TYPES:
        raise ValueError(
            f"Unsupported file type: {ext}. Supported: {', '.join(SUPPORTED_TYPES)}"
        )

    if ext == ".pdf":
        return process_pdf_file(file_bytes)
    else:
        return process_image_file(file_bytes)
