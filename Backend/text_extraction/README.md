# Text Extraction Module

Standalone extractor for Study Studio uploads. It turns PDF, DOCX, PPTX, TXT,
and Markdown files into clean text that is ready for chunking.

## Contract

```python
extract_text(filename, mime, data) -> str
```

- `filename`: original uploaded filename
- `mime`: uploaded MIME type
- `data`: raw file bytes
- returns: cleaned text

Unsupported or corrupt files raise `ExtractionError` with a clear message.

## Setup

```bash
cd Backend/text_extraction
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run Tests

```bash
pytest -q
```

## Run Demo API

```bash
uvicorn api:app --reload
```

Then upload a file:

```bash
curl -X POST http://127.0.0.1:8000/extract \
  -F "file=@sample.pdf"
```

Response:

```json
{
  "filename": "sample.pdf",
  "mime": "application/pdf",
  "text": "Clean extracted text..."
}
```

## Integration

The lead can import the extractor and call it from the ingestion pipeline:

```python
from text_extraction import extract_text

text = extract_text(filename, mime, data)
```

