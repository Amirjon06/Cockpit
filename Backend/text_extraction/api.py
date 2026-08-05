from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel

from text_extraction import ExtractionError, extract_text

app = FastAPI(title="Text Extraction Demo")


class ExtractResponse(BaseModel):
    filename: str
    mime: str
    text: str


@app.post("/extract", response_model=ExtractResponse)
async def extract(file: UploadFile = File(...)):
    filename = file.filename or "upload"
    mime = file.content_type or ""
    data = await file.read()

    try:
        text = extract_text(filename, mime, data)
    except ExtractionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {"filename": filename, "mime": mime, "text": text}
