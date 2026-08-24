import json

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse

from app.agents.hein import HeinAgent
from app.agents.lily import LilyAgent
from app.agents.lucas import LucasAgent
from app.model_client import ModelClient


app = FastAPI(title="Guided Generation Agents")

secondary_model_client = ModelClient("OPENROUTER_SECONDARY_MODEL")
primary_model_client = ModelClient("OPENROUTER_PRIMARY_MODEL")
hein = HeinAgent(secondary_model_client)
lily = LilyAgent(secondary_model_client)
lucas = LucasAgent(primary_model_client)


def sse_event(name: str, data=None) -> str:
    payload = {} if data is None else data
    return f"event: {name}\ndata: {json.dumps(payload)}\n\n"


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "guided-generation-python-agents",
    }


@app.post("/agents/hein/analyze")
async def analyze_assignment(payload: dict):
    try:
        return await hein.analyze(payload)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/agents/lily/generate")
async def generate_outline(payload: dict):
    try:
        return await lily.generate(payload)
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/agents/lucas/generate")
async def generate_essay(payload: dict):
    async def stream():
        try:
            async for delta in lucas.generate_stream(payload):
                yield sse_event("delta", {"text": delta})
            client = getattr(lucas, "model_client", primary_model_client)
            yield sse_event("meta", {"model": client.model})
            yield sse_event("done")
        except ValueError as error:
            yield sse_event("error", {"message": str(error), "status": 400})
        except Exception as error:
            yield sse_event("error", {"message": str(error), "status": 502})

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
