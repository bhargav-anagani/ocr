from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class OCRResult(BaseModel):
    id: str
    user_id: str
    filename: str
    file_type: str
    extracted_text: str
    confidence: float
    word_count: int
    page_count: int
    created_at: datetime


class OCRResultCreate(BaseModel):
    user_id: str
    filename: str
    file_type: str
    extracted_text: str
    confidence: float
    word_count: int
    page_count: int = 1


class OCRResponse(BaseModel):
    id: str
    filename: str
    file_type: str
    extracted_text: str
    confidence: float
    word_count: int
    page_count: int
    created_at: datetime


class OCRHistoryItem(BaseModel):
    id: str
    filename: str
    file_type: str
    word_count: int
    confidence: float
    page_count: int
    created_at: datetime
    preview: str  # First 150 chars of extracted text


class PaginatedHistory(BaseModel):
    items: list[OCRHistoryItem]
    total: int
    page: int
    per_page: int
    total_pages: int
