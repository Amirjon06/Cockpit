# Guided Generation backend

Guided Generation is split into a Go API on port `8200` and a Python agent
service on port `8201`.

The generation pipeline is:

1. Hein analyzes assignment instructions.
2. Lily creates an editable outline.
3. Lucas writes and streams a source-grounded essay.

## Run locally

From `python_agents`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:OPENROUTER_API_KEY = "your-key"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --port 8201
```

From `go_api` in a second terminal:

```powershell
$env:PYTHON_AGENT_URL = "http://localhost:8201"
go run .\cmd\server
```

The public Go routes are:

- `POST /api/guided-generation/analyze`
- `POST /api/guided-generation/outlines`
- `POST /api/guided-generation/generate`

## Lucas contract

Lucas accepts the outputs from Hein and Lily plus the selected source and
customization state. `outlines` and `sources` must each contain at least one
object. The frontend aliases `outline`, `selectedSources`, and `citation` are
also accepted.

```json
{
  "analysis": "What the assignment requires",
  "essayTopic": "Renewable energy policy",
  "essayType": "Comparative",
  "scope": "Two national policies",
  "structure": "Introduction, comparison, conclusion",
  "instructions": "Optional original assignment instructions",
  "outlines": [
    {
      "type": "Introduction",
      "title": "Policy tradeoffs",
      "description": "Introduce the comparison",
      "bullets": ["State the thesis"]
    }
  ],
  "sources": [
    {
      "id": "source-1",
      "title": "Energy Outlook",
      "author": "A. Researcher",
      "domain": "example.org",
      "year": 2025,
      "kind": "report",
      "origin": "manual",
      "snippet": "Relevant source excerpt"
    }
  ],
  "tone": "Academic",
  "length": "Standard",
  "citationStyle": "APA"
}
```

Supported choices match the customization frontend:

- Tone: `Academic`, `Neutral`, or `Persuasive`
- Length: `Concise`, `Standard`, or `In-depth`
- Citation style: `APA`, `MLA`, or `Chicago`

The generation endpoint returns `text/event-stream` with the same event
convention used elsewhere in Cockpit:

```text
event: delta
data: {"text":"generated text"}

event: meta
data: {"model":"openai/gpt-4o-mini"}

event: done
data: {}
```

Failures are returned as terminal `error` events with `message` and `status`
fields. Lucas instructs the model to ground factual claims in numbered source
blocks and never invent missing source metadata.

## Tests

```powershell
cd python_agents
.\.venv\Scripts\python.exe -m unittest discover -s tests -v

cd ..\go_api
go test ./...
```
