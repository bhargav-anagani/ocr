import math
from datetime import datetime
from pathlib import Path

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import StreamingResponse
from fastapi.concurrency import run_in_threadpool
import io

from app.config import settings
from app.database import get_database
from app.models.ocr_result import OCRHistoryItem, OCRResponse, PaginatedHistory
from app.services.auth_service import get_current_user
from app.services.ocr_service import process_file, SUPPORTED_TYPES

router = APIRouter(prefix="/api/ocr", tags=["OCR"])

MAX_BYTES = settings.MAX_FILE_SIZE_MB * 1024 * 1024


@router.post("/upload", response_model=OCRResponse, status_code=status.HTTP_201_CREATED)
async def upload_and_ocr(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    """Upload an image or PDF and run OCR on it."""
    # Validate file extension
    ext = Path(file.filename).suffix.lower()
    if ext not in SUPPORTED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unsupported file type '{ext}'. Supported: jpg, jpeg, png, bmp, tiff, webp, pdf",
        )

    # Read and size-check
    file_bytes = await file.read()
    if len(file_bytes) > MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds maximum allowed size of {settings.MAX_FILE_SIZE_MB} MB",
        )

    # Run OCR
    try:
        extracted_text, confidence, page_count = await run_in_threadpool(
            process_file, file_bytes, file.filename
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OCR processing failed: {str(e)}",
        )

    if not extracted_text.strip():
        extracted_text = "[No text detected in this image]"

    word_count = len(extracted_text.split()) if extracted_text.strip() else 0

    # Save to MongoDB
    db = get_database()
    doc = {
        "user_id": str(current_user["_id"]),
        "filename": file.filename,
        "file_type": ext.lstrip(".").upper(),
        "extracted_text": extracted_text,
        "confidence": confidence,
        "word_count": word_count,
        "page_count": page_count,
        "created_at": datetime.utcnow(),
    }
    result = await db.ocr_results.insert_one(doc)

    return OCRResponse(
        id=str(result.inserted_id),
        filename=file.filename,
        file_type=doc["file_type"],
        extracted_text=extracted_text,
        confidence=confidence,
        word_count=word_count,
        page_count=page_count,
        created_at=doc["created_at"],
    )


@router.get("/history", response_model=PaginatedHistory)
async def get_history(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, ge=1, le=50),
    current_user: dict = Depends(get_current_user),
):
    """Get paginated OCR history for the current user."""
    db = get_database()
    user_id = str(current_user["_id"])

    total = await db.ocr_results.count_documents({"user_id": user_id})
    skip = (page - 1) * per_page

    cursor = (
        db.ocr_results.find({"user_id": user_id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(per_page)
    )
    docs = await cursor.to_list(length=per_page)

    items = [
        OCRHistoryItem(
            id=str(doc["_id"]),
            filename=doc["filename"],
            file_type=doc["file_type"],
            word_count=doc["word_count"],
            confidence=doc["confidence"],
            page_count=doc.get("page_count", 1),
            created_at=doc["created_at"],
            preview=doc["extracted_text"][:150] + ("..." if len(doc["extracted_text"]) > 150 else ""),
        )
        for doc in docs
    ]

    return PaginatedHistory(
        items=items,
        total=total,
        page=page,
        per_page=per_page,
        total_pages=math.ceil(total / per_page) if total > 0 else 1,
    )


@router.get("/{result_id}", response_model=OCRResponse)
async def get_result(
    result_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get a specific OCR result by ID."""
    db = get_database()
    try:
        doc = await db.ocr_results.find_one({"_id": ObjectId(result_id)})
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid result ID")

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Result not found")

    if doc["user_id"] != str(current_user["_id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    return OCRResponse(
        id=str(doc["_id"]),
        filename=doc["filename"],
        file_type=doc["file_type"],
        extracted_text=doc["extracted_text"],
        confidence=doc["confidence"],
        word_count=doc["word_count"],
        page_count=doc.get("page_count", 1),
        created_at=doc["created_at"],
    )


@router.get("/download/{result_id}")
async def download_text(
    result_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Download extracted text as a .txt file."""
    db = get_database()
    try:
        doc = await db.ocr_results.find_one({"_id": ObjectId(result_id)})
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid result ID")

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Result not found")

    if doc["user_id"] != str(current_user["_id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    filename_stem = Path(doc["filename"]).stem
    output_filename = f"{filename_stem}_ocr_result.txt"
    text_bytes = doc["extracted_text"].encode("utf-8")

    return StreamingResponse(
        io.BytesIO(text_bytes),
        media_type="text/plain; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{output_filename}"'},
    )


@router.delete("/{result_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_result(
    result_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Delete an OCR result from history."""
    db = get_database()
    try:
        doc = await db.ocr_results.find_one(
            {"_id": ObjectId(result_id), "user_id": str(current_user["_id"])}
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid result ID")

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Result not found")

    await db.ocr_results.delete_one({"_id": ObjectId(result_id)})


@router.get("/stats/summary")
async def get_stats(current_user: dict = Depends(get_current_user)):
    """Get OCR usage stats for the current user."""
    db = get_database()
    user_id = str(current_user["_id"])

    pipeline = [
        {"$match": {"user_id": user_id}},
        {
            "$group": {
                "_id": None,
                "total_files": {"$sum": 1},
                "total_words": {"$sum": "$word_count"},
                "avg_confidence": {"$avg": "$confidence"},
                "total_pages": {"$sum": "$page_count"},
            }
        },
    ]

    cursor = db.ocr_results.aggregate(pipeline)
    results = await cursor.to_list(length=1)

    if results:
        stats = results[0]
        return {
            "total_files": stats["total_files"],
            "total_words": stats["total_words"],
            "avg_confidence": round(stats["avg_confidence"], 1),
            "total_pages": stats["total_pages"],
        }

    return {"total_files": 0, "total_words": 0, "avg_confidence": 0.0, "total_pages": 0}
